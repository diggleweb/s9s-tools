#! /bin/bash
MYNAME=$(basename $0)
MYBASENAME=$(basename $0 .sh)
MYDIR=$(dirname $0)
STDOUT_FILE=ft_errors_stdout
VERBOSE=""
LOG_OPTION="--wait"
CLUSTER_NAME="${MYBASENAME}_$$"
CLUSTER_ID=""
ALL_CREATED_IPS=""
OPTION_INSTALL=""
PIP_CONTAINER_CREATE=$(which "pip-container-create")

# This is the name of the server that will hold the linux containers.
CONTAINER_SERVER="core1"

# The IP of the node we added first and last. Empty if we did not.
FIRST_ADDED_NODE=""
LAST_ADDED_NODE=""

cd $MYDIR
source ./include.sh

#
# Prints usage information and exits.
#
function printHelpAndExit()
{
cat << EOF
Usage: 
  $MYNAME [OPTION]... [TESTNAME]
 
  $MYNAME - Test script for s9s to check Galera clusters.

 -h, --help       Print this help and exit.
 --verbose        Print more messages.
 --log            Print the logs while waiting for the job to be ended.
 --server=SERVER  The name of the server that will hold the containers.
 --print-commands Do not print unit test info, print the executed commands.
 --install        Just install the cluster and exit.
 --reset-config   Remove and re-generate the ~/.s9s directory.

EXAMPLE
 ./ft_galera.sh --print-commands --server=storage01 --reset-config --install
EOF
    exit 1
}


ARGS=$(\
    getopt -o h \
        -l "help,verbose,log,server:,print-commands,install,reset-config" \
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
            ;;

        --log)
            shift
            LOG_OPTION="--log"
            ;;

        --server)
            shift
            CONTAINER_SERVER="$1"
            shift
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

        --)
            shift
            break
            ;;
    esac
done

if [ -z "$S9S" ]; then
    echo "The s9s program is not installed."
    exit 7
fi

#CLUSTER_ID=$($S9S cluster --list --long --batch | awk '{print $1}')

if [ -z $(which pip-container-create) ]; then
    printError "The 'pip-container-create' program is not found."
    printError "Don't know how to create nodes, giving up."
    exit 1
fi

#
#
#
function testPing()
{
    print_title "Pinging controller."

    #
    # Pinging. 
    #
    mys9s cluster --ping 

    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while pinging controller."
        #pip-say "The controller is off line. Further testing is not possible."
    #else
        #pip-say "The controller is on line."
    fi
}

#
# This test will allocate a few nodes and install a new cluster.
#
function testCreateCluster()
{
    local nodes
    local nodeName
    local exitCode

    print_title "Testing the creation of a Galera cluster"

    nodeName=$(create_node)
    nodes+="$nodeName;"
    FIRST_ADDED_NODE=$nodeName
    ALL_CREATED_IPS+=" $nodeName"
    
    nodeName=$(create_node)
    nodes+="$nodeName;"
    ALL_CREATED_IPS+=" $nodeName"
    
    nodeName=$(create_node)
    nodes+="$nodeName"
    ALL_CREATED_IPS+=" $nodeName"
    
    #
    # Creating a Galera cluster.
    #
    mys9s cluster \
        --create \
        --cluster-type=galera \
        --nodes="$nodes" \
        --vendor=percona \
        --cluster-name="$CLUSTER_NAME" \
        --provider-version=5.6 \
        $LOG_OPTION

    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while creating cluster."
    fi

    CLUSTER_ID=$(find_cluster_id $CLUSTER_NAME)
    if [ "$CLUSTER_ID" -gt 0 ]; then
        printVerbose "Cluster ID is $CLUSTER_ID"
    else
        failure "Cluster ID '$CLUSTER_ID' is invalid"
    fi
}

#
# This function will check the basic getconfig/setconfig features that reads the
# configuration of one node.
#
function testConfig()
{
    local exitCode
    local value
    local newValue
    local name

    printVerbose "Checking the configuration"

    #
    # Listing the configuration values. The exit code should be 0.
    #
    mys9s node \
        --list-config \
        --nodes=$FIRST_ADDED_NODE #\ >/dev/null

    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi

    #
    # Changing a configuration value.
    #
    newValue=200
    name="max_connections"
    
    mys9s node \
        --change-config \
        --nodes=$FIRST_ADDED_NODE \
        --opt-name=$name \
        --opt-group=MYSQLD \
        --opt-value=$newValue
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
    
    #
    # Reading the configuration back. This time we only read one value.
    #
    value=$($S9S node \
            --batch \
            --list-config \
            --opt-name=$name \
            --nodes=$FIRST_ADDED_NODE |  awk '{print $3}')

    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi

    if [ "$value" != "$newValue" ]; then
        failure "Configuration value should be $newValue not $value"
    fi

    mys9s node \
        --list-config \
        --nodes=$FIRST_ADDED_NODE \
        $name
}

#
# This test will set a configuration value that contains an SI prefixum,
# ("54M").
#
function testSetConfig()
{
    local exitCode
    local value
    local newValue="64M"
    local name="max_heap_table_size"

    #
    # Changing a configuration value.
    #
    mys9s node \
        --change-config \
        --nodes=$FIRST_ADDED_NODE \
        --opt-name=$name \
        --opt-group=MYSQLD \
        --opt-value=$newValue
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
    
    #
    # Reading the configuration back. This time we only read one value.
    #
    value=$($S9S node \
            --batch \
            --list-config \
            --opt-name=$name \
            --nodes=$FIRST_ADDED_NODE |  awk '{print $3}')

    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi

    if [ "$value" != "$newValue" ]; then
        failure "Configuration value should be $newValue not $value"
    fi

    mys9s node \
        --list-config \
        --nodes=$FIRST_ADDED_NODE \
        'max*'
}

#
# This test will call a --restart on the node.
#
function testRestartNode()
{
    local exitCode

    #
    # Restarting a node. 
    #
    mys9s node \
        --restart \
        --cluster-id=$CLUSTER_ID \
        --nodes=$FIRST_ADDED_NODE \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This test will first call a --stop then a --start on a node. Pretty basic
# stuff.
#
function testStopStartNode()
{
    local exitCode

    #
    # First stop.
    #
    mys9s node \
        --stop \
        --cluster-id=$CLUSTER_ID \
        --nodes=$FIRST_ADDED_NODE \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
    
    #
    # Then start.
    #
    mys9s node \
        --start \
        --cluster-id=$CLUSTER_ID \
        --nodes=$FIRST_ADDED_NODE \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# Creating a new account on the cluster.
#
function testCreateAccount()
{
    local userName

    print_title "Testing account creation."

    #
    # This command will create a new account on the cluster.
    #
    if [ -z "$CLUSTER_ID" ]; then
        failure "No cluster ID found."
        return 1
    fi

    mys9s account \
        --create \
        --cluster-id=$CLUSTER_ID \
        --account="john_doe:password@1.2.3.4" \
        --with-database
    
    exitCode=$?
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while creating an account."
    fi

    userName=$(s9s account --list --cluster-id=1 john_doe)
    if [ "$userName" != "john_doe" ]; then
        failure "Failed to create user 'john_doe'."
    fi
}


#
# Creating a new database on the cluster.
#
function testCreateDatabase()
{
    local userName

    print_title "Testing database creation."

    #
    # This command will create a new database on the cluster.
    #
    mys9s cluster \
        --create-database \
        --cluster-id=$CLUSTER_ID \
        --db-name="testCreateDatabase" \
        --batch
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while creating a database."
    fi
    
    #
    # This command will create a new account on the cluster and grant some
    # rights to the just created database.
    #
    mys9s account \
        --create \
        --cluster-id=$CLUSTER_ID \
        --account="pipas:password" \
        --privileges="testCreateDatabase.*:INSERT,UPDATE" \
        --batch
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while creating account."
    fi
   
    userName=$(s9s account --list --cluster-id=1 pipas)
    if [ "$userName" != "pipas" ]; then
        failure "Failed to create user 'pipas'."
    fi

    #
    # This command will create a new account on the cluster and grant some
    # rights to the just created database.
    #
    mys9s account \
        --grant \
        --cluster-id=$CLUSTER_ID \
        --account="pipas" \
        --privileges="testCreateDatabase.*:DELETE,TRUNCATE" \
        --batch 
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while granting privileges."
    fi
}

#
# This test will create a user and a database and then upload some data if the
# data can be found on the local computer.
#
function testUploadData()
{
    local db_name="pipas1"
    local user_name="pipas1"
    local password="p"
    local reply
    local count=0

    print_title "Testing data upload on cluster."

    #
    # Creating a new database on the cluster.
    #
    mys9s cluster \
        --create-database \
        --db-name=$db_name
    
    exitCode=$?
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is $exitCode while creating a database."
        return 1
    fi

    #
    # Creating a new account on the cluster.
    #
    mys9s account \
        --create \
        --account="$user_name:$password" \
        --privileges="$db_name.*:ALL"
    
    exitCode=$?
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is $exitCode while creating a database."
        return 1
    fi

    #
    # Executing a simple SQL statement using the account we created.
    #
    reply=$(\
        mysql \
            --disable-auto-rehash \
            --batch \
            -h$FIRST_ADDED_NODE \
            -u$user_name \
            -p$password \
            $db_name \
            -e "SELECT 41+1" | tail -n +2 )

    if [ "$reply" != "42" ]; then
        echo "Cluster failed to execute an SQL statement: '$reply'."
    fi

    #
    # Here we upload some tables. This part needs test data...
    #
    for file in /home/pipas/Desktop/stuff/databases/*.sql.gz; do
        if [ ! -f "$file" ]; then
            continue
        fi

        printf "%'6d " "$count"
        printf "$XTERM_COLOR_RED$file$TERM_NORMAL"
        printf "\n"
        zcat $file | \
            mysql --batch -h$FIRST_ADDED_NODE -u$user_name -pp $db_name

        exitCode=$?
        if [ "$exitCode" -ne 0 ]; then
            failure "Exit code is $exitCode while uploading data."
            break
        fi

        let count+=1
        if [ "$count" -gt 99 ]; then
            break
        fi
    done
}

#
# This test will add one new node to the cluster.
#
function testAddNode()
{
    local nodes
    local exitCode

    print_title "Addiong a node"
    printVerbose "Creating node..."
    LAST_ADDED_NODE=$(create_node)
    nodes+="$LAST_ADDED_NODE"
    ALL_CREATED_IPS+=" $LAST_ADDED_NODE"

    #
    # Adding a node to the cluster.
    #
    mys9s cluster \
        --add-node \
        --cluster-id=$CLUSTER_ID \
        --nodes="$nodes" \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This test will add a proxy sql node.
#
function testAddProxySql()
{
    local node
    local nodes
    local exitCode

    print_title "The test to add ProxySQL node is starting now."
    printVerbose "Creating Node..."
    nodeName=$(create_node)
    nodes+="proxySql://$nodeName"
    ALL_CREATED_IPS+=" $nodeName"

    #
    # Adding a node to the cluster.
    #
    mys9s cluster \
        --add-node \
        --cluster-id=$CLUSTER_ID \
        --nodes="$nodes" \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi

    mys9s node \
        --list-config \
        --nodes=$nodeName 
}

#
# This test will first add a HaProxy node, then remove from the cluster. The
# idea behind this test is that the remove-node call should be identify the node
# using the IP address if there are multiple nodes with the same IP (one galera
# node and one haproxy node on the same host this time).
#
function testAddRemoveHaProxy()
{
    local node
    local nodes
    local exitCode
    
    print_title "The test to add and remove HaProxy node is starting now."
    node=$(\
        $S9S node --list --long --batch | \
        grep ^g | \
        tail -n1 | \
        awk '{print $5}')

    #
    # Adding a node to the cluster.
    #
    printVerbose "Adding haproxy at '$node'."
    mys9s cluster \
        --add-node \
        --cluster-id=$CLUSTER_ID \
        --nodes="haProxy://$node" \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
   
    mys9s node --list --long --color=always

    #
    # Remove a node to the cluster.
    #
    printVerbose "Removing haproxy at '$node:9600'."
    mys9s cluster \
        --remove-node \
        --cluster-id=$CLUSTER_ID \
        --nodes="$node:9600" \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
    
    mys9s node --list --long --color=always
}

#
# This test will add a HaProxy node.
#
function testAddHaProxy()
{
    local node
    local nodes
    local exitCode
    
    print_title "The test to add HaProxy node is starting now."
    printVerbose "Creating Node..."
    node=$(create_node)
    nodes+="haProxy://$node"
    ALL_CREATED_IPS+=" $node"

    #
    # Adding haproxy to the cluster.
    #
    mys9s cluster \
        --add-node \
        --cluster-id=$CLUSTER_ID \
        --nodes="$nodes" \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This test will remove the last added node.
#
function testRemoveNode()
{
    if [ -z "$LAST_ADDED_NODE" ]; then
        printVerbose "Skipping test."
    fi
    
    print_title "The test to remove node is starting now."
    
    #
    # Removing the last added node.
    #
    mys9s cluster \
        --remove-node \
        --cluster-id=$CLUSTER_ID \
        --nodes="$LAST_ADDED_NODE" \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This will perform a rolling restart on the cluster
#
function testRollingRestart()
{
    local exitCode
    
    print_title "The test of rolling restart is starting now."

    #
    # Calling for a rolling restart.
    #
    mys9s cluster \
        --rolling-restart \
        --cluster-id=$CLUSTER_ID \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This will create a backup. Here we pass the backup-dir, so this should work
# even if the backup directory is not set in the config.
#
function testCreateBackup()
{
    local exitCode
    
    print_title "The test to create a backup is starting."

    #
    # Calling for a rolling restart.
    #
    mys9s backup \
        --create \
        --cluster-id=$CLUSTER_ID \
        --nodes=$FIRST_ADDED_NODE \
        --backup-dir=/tmp \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This will restore a backup. 
#
function testRestoreBackup()
{
    local exitCode
    local backupId

    print_title "The test to restore a backup is starting."
    backupId=$(\
        $S9S backup --list --long --batch --cluster-id=$CLUSTER_ID |\
        awk '{print $1}')

    #
    # Creating a backup. 
    #
    mys9s backup \
        --restore \
        --cluster-id=$CLUSTER_ID \
        --backup-id=$backupId \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# This will remove a backup. 
#
function testRemoveBackup()
{
    local exitCode
    local backupId

    print_title "The test to remove a backup is starting."
    backupId=$(\
        $S9S backup --list --long --batch --cluster-id=$CLUSTER_ID |\
        awk '{print $1}')

    #
    # Calling for a rolling restart.
    #
    mys9s backup \
        --delete \
        --backup-id=$backupId \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# Stopping the cluster.
#
function testStop()
{
    local exitCode

    print_title "The test to stop the cluster is starting now."

    #
    # Stopping the cluster.
    #
    mys9s cluster \
        --stop \
        --cluster-id=$CLUSTER_ID \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# Starting the cluster.
#
function testStart()
{
    local exitCode

    print_title "The test to start the cluster is starting now."

    #
    # Starting the cluster.
    #
    mys9s cluster \
        --start \
        --cluster-id=$CLUSTER_ID \
        $LOG_OPTION
    
    exitCode=$?
    printVerbose "exitCode = $exitCode"
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"
    fi
}

#
# Running the requested tests.
#
startTests

reset_config
grant_user

if [ "$OPTION_INSTALL" ]; then
    runFunctionalTest testCreateCluster
elif [ "$1" ]; then
    for testName in $*; do
        runFunctionalTest "$testName"
    done
else
    runFunctionalTest testPing

    runFunctionalTest testCreateCluster

    runFunctionalTest testConfig
    runFunctionalTest testSetConfig

    runFunctionalTest testRestartNode
    runFunctionalTest testStopStartNode

    runFunctionalTest testCreateAccount
    runFunctionalTest testCreateDatabase
    runFunctionalTest testUploadData

    runFunctionalTest testAddNode
    runFunctionalTest testAddProxySql
    runFunctionalTest testAddRemoveHaProxy
    runFunctionalTest testAddHaProxy
    runFunctionalTest testRemoveNode
    runFunctionalTest testRollingRestart
    runFunctionalTest testCreateBackup
    runFunctionalTest testRestoreBackup
    runFunctionalTest testRemoveBackup
    runFunctionalTest testStop
    runFunctionalTest testStart
fi

endTests


