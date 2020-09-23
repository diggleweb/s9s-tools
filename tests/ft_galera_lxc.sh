#! /bin/bash
MYNAME=$(basename "$0")
MYBASENAME=$(basename "$0" .sh)
MYDIR=$(dirname "$0")
VERBOSE=""
VERSION="0.0.3"

LOG_OPTION="--wait"
DEBUG_OPTION=""

CONTAINER_SERVER=""
CONTAINER_IP=""
CLUSTER_NAME="${MYBASENAME}_$$"
LAST_CONTAINER_NAME=""
OPTION_VENDOR="mariadb"
PROVIDER_VERSION="10.2"

cd $MYDIR
source ./include.sh
source ./shared_test_cases.sh
source ./include_lxc.sh

#
# Prints usage information and exits.
#
function printHelpAndExit()
{
cat << EOF
Usage: $MYNAME [OPTION]... [TESTNAME]

 $MYNAME - Test script for s9s to check Galera on LXC.

  -h, --help       Print this help and exit.
  --verbose        Print more messages.
  --print-json     Print the JSON messages sent and received.
  --log            Print the logs while waiting for the job to be ended.
  --print-commands Do not print unit test info, print the executed commands.
  --install        Just install the server and exit.
  --reset-config   Remove and re-generate the ~/.s9s directory.
  --server=SERVER  Use the given server to create containers.

SUPPORTED TESTS:
  o registerServer   Creates a new cmon-cloud container server. 
  o createCluster    Creates a cluster on VMs created on the fly.
  o dropCluster      Drops the created cluster.
  o deleteContainer  Deletes all the containers that were created.
  o unregisterServer Unregistering cmon-cloud server.

EOF
    exit 1
}

ARGS=$(\
    getopt -o h \
        -l "help,verbose,print-json,log,print-commands,install,reset-config,\
server:" \
        -- "$@")

if [ $? -ne 0 ]; then
    exit 6
fi

eval set -- "$ARGS"
while true; do
    case "$1" in
        -h|--help)
            shift
            printHelpAndExit
            ;;

        --verbose)
            shift
            VERBOSE="true"
            OPTION_VERBOSE="--verbose"
            ;;

        --log)
            shift
            LOG_OPTION="--log"
            DEBUG_OPTION="--debug"
            ;;

        --print-json)
            shift
            OPTION_PRINT_JSON="--print-json"
            ;;

        --print-commands)
            shift
            DONT_PRINT_TEST_MESSAGES="true"
            PRINT_COMMANDS="true"
            ;;

        --install)
            shift
            OPTION_INSTALL="--install"
            ;;

        --reset-config)
            shift
            OPTION_RESET_CONFIG="true"
            ;;

        --server)
            shift
            CONTAINER_SERVER="$1"
            shift
            ;;

        --)
            shift
            break
            ;;
    esac
done

if [ -z "$OPTION_RESET_CONFIG" ]; then
    printError "This script must remove the s9s config files."
    printError "Make a copy of ~/.s9s and pass the --reset-config option."
    exit 6
fi

if [ -z "$CONTAINER_SERVER" ]; then
    printError "No container server specified."
    printError "Use the --server command line option to set the server."
    exit 6
fi

function createCluster()
{
    local node001="ft_galera_lxc_01_$$"
    local node002="ft_galera_lxc_02_$$"
    local exit_code

    #
    # Creating a Cluster.
    #
    print_title "Creating a Cluster"
    begin_verbatim
    mys9s cluster \
        --create \
        --template="ubuntu" \
        --cluster-name="$CLUSTER_NAME" \
        --cluster-type=galera \
        --provider-version="$PROVIDER_VERSION" \
        --vendor=$OPTION_VENDOR \
        --nodes="$node001;$node002" \
        --containers="$node001;$node002" \
        $LOG_OPTION \
        $DEBUG_OPTION

    exit_code=$?
    check_exit_code $exit_code
    if [ $exit_code -ne 0 ]; then
        end_verbatim
        return 1
    fi

    counter=0
    while true; do 
        CLUSTER_ID=$(find_cluster_id $CLUSTER_NAME)
        
        if [ "$CLUSTER_ID" != 'NOT-FOUND' ]; then
            break;
        fi

        echo "Cluster '$CLUSTER_NAME' not found."
        s9s cluster --list --long
        [ "$counter" -gt 5 ] && break
        sleep 5
        let counter+=1
    done

    if [ "$CLUSTER_ID" -gt 0 2>/dev/null ]; then
        printVerbose "Cluster ID is $CLUSTER_ID"
    else
        failure "Cluster ID '$CLUSTER_ID' is invalid"
    fi

    check_container_ids --galera-nodes

    wait_for_cluster_started "$CLUSTER_NAME"
    end_verbatim
}

function testAlarms()
{
    local node002="ft_galera_lxc_02_$$"
    local n_alarms

    print_title "Check for Degraded Cluster"
    cat <<EOF | paragraph
  This test will stop a container then check if that is noticed by the
  controller, the state of the cluster is changed, the alarm is created, the
  incident report is created and so on.

EOF
    begin_verbatim

    mys9s cluster --stat
    mys9s report --list --cluster-id=1 --long
    mys9s alarm --list --long 
    
    n_alarms=$(s9s alarm --list --long --batch | wc -l)
    if [ "$n_alarms" -gt 0 ]; then
        failure "There are $n_alarms alarm(s), there should be none."
    else
        success "  o There are no alarms, ok."
    fi

    #
    # Stopping a container.
    #
    mys9s container --stop "$node002" --wait
    mysleep 15
    
    wait_for_cluster_state "$CLUSTER_NAME" "DEGRADED"

    mys9s report --list --cluster-id=1 --long
    mys9s alarm --list --long 

    check_alarm_statistics         \
        --cluster-id     1         \
        --check-metatype           \
        --should-have_critical

    n_alarms=$(s9s alarm --list --long --batch | wc -l)
    if [ "$n_alarms" -lt 1 ]; then
        failure "There are $n_alarms, there should be at least one."
    else
        success "  o There is at least one alarm, ok."
    fi

    end_verbatim

    #
    # Starting the container.
    #
    print_title "Starting the Container Again"
    cat <<EOF | paragraph
  Here we start the container again, check that the cluster goes into started
  state again and the alarm disappears.
EOF

    begin_verbatim

    mys9s container --start "$node002"
    wait_for_cluster_state "$CLUSTER_NAME" "STARTED"
    #mysleep 60

    mys9s alarm --list --long 
    mys9s cluster --stat

    n_alarms=$(s9s alarm --list --long --batch | wc -l)
    if [ "$n_alarms" -gt 0 ]; then
        failure "There are $n_alarms alarm(s), there should be none."
    else
        success "  o The alarm disappeared, ok."
    fi

    end_verbatim
}

function dropCluster()
{
    local old_ifs="$IFS"
    local line
    local name

    #
    # Dropping the cluster.
    #
    print_title "Dropping Cluster"
    begin_verbatim
    mys9s cluster \
        --drop \
        --cluster-id="$CLUSTER_ID" \
        $LOG_OPTION \
        $DEBUG_OPTION

    mys9s tree --list --long

    #
    # Checking.
    #
    IFS=$'\n'
    for line in $(s9s tree --list --long --batch); do
        echo "  checking line: $line"
        line=$(echo "$line" | sed 's/1, 0/   -/g')
        name=$(echo "$line" | awk '{print $5}')

        case "$name" in
            $CLUSTER_NAME)
                failure "Cluster found after it is dropped."
                ;;
        esac
    done
    IFS=$old_ifs  
    end_verbatim
}

#
# This will delete the containers we created before.
#
function deleteContainer()
{
    local containers
    local container

    containers+=" ft_galera_lxc_01_$$"
    containers+=" ft_galera_lxc_02_$$"

    print_title "Deleting Containers"
    begin_verbatim
    #
    # Deleting all the containers we created.
    #
    for container in $containers; do
        mys9s container \
            --cmon-user=system \
            --password=secret \
            --delete \
            $LOG_OPTION \
            $DEBUG_OPTION \
            "$container"
    
        check_exit_code $?
    done

    s9s job --list
    end_verbatim
}

function unregisterServer()
{
    if [ -n "$CONTAINER_SERVER" ]; then
        print_title "Unregistering Cmon-cloud server"
        begin_verbatim
        mys9s server \
            --unregister \
            --servers="cmon-cloud://$CONTAINER_SERVER"

        check_exit_code_no_job $?
        end_verbatim
    fi

}


#
# Running the requested tests.
#
startTests
reset_config
grant_user

if [ "$OPTION_INSTALL" ]; then
    if [ -n "$1" ]; then
        for testName in $*; do
            runFunctionalTest "$testName"
        done
    else
        runFunctionalTest registerServer
        runFunctionalTest createCluster
        runFunctionalTest testAlarms
    fi
elif [ "$1" ]; then
    for testName in $*; do
        runFunctionalTest "$testName"
    done
else
    runFunctionalTest registerServer
    runFunctionalTest createCluster
    runFunctionalTest testAlarms
    runFunctionalTest dropCluster
    runFunctionalTest --force deleteContainer
    runFunctionalTest unregisterServer
fi

endTests
