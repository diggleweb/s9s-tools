/*
 * Severalnines Tools
 * Copyright (C) 2016  Severalnines AB
 *
 * This file is part of s9s-tools.
 *
 * s9s-tools is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * s9s-tools is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with s9s-tools. If not, see <http://www.gnu.org/licenses/>.
 */
#pragma once

#include "S9sString"
#include "S9sRpcReply"

class S9sRpcClientPrivate;
class S9sUser;

class S9sRpcClient
{
    public:
        S9sRpcClient();

        S9sRpcClient(
                const S9sString &hostName,
                const int        port,
                const bool       useTls);

        S9sRpcClient(const S9sRpcClient &orig);

        virtual ~S9sRpcClient();


        S9sRpcClient &operator=(const S9sRpcClient &rhs);

        bool hasPrivateKey() const;
        bool canAuthenticate(S9sString &reason) const;
        bool needToAuthenticate() const;

        const S9sRpcReply &reply() const;
        void setExitStatus();

        S9sString errorString() const;
        void printMessages(
                const S9sString &defaultMessage,
                bool             success);

        bool authenticate();
        bool authenticateWithKey();
        bool authenticateWithPassword();

        /*
         * The executers that send an RPC request and receive an RPC reply from
         * the server.
         */
        bool getClusters();
        bool getCluster();
        
        bool getConfig(const S9sVariantList &hosts);
        bool setConfig(const S9sVariantList &hosts);

        bool ping();

        bool setHost();
        
        bool setHost(
                const S9sVariantList &hosts,
                const S9sVariantMap  &properties);

        bool getCpuInfo(const int clusterId);
        bool getInfo();
        
        
        bool getStats(
                const int        clusterId,
                const S9sString &statName);

        bool getCpuStats(const int clusterId);
        bool getSqlStats(const int clusterId);
        bool getMemStats(const int clusterId);

        bool getMetaTypes();
        bool getMetaTypeProperties(const S9sString &typeName);
        bool getMemoryStats(const int clusterId);

        bool getRunningProcesses();

        bool getJobInstances();
        
        /*
         * Backup related methods.
         */
        bool createBackup();
        bool restoreBackup();
        
        bool getBackups(const int clusterId);
        bool deleteBackupRecord(const ulonglong backupId);

        /*
         * Account&database handling.
         */
        bool createAccount();

        bool grantPrivileges(
                const S9sAccount &account,
                const S9sString  &privileges);

        bool deleteAccount();
        bool createDatabase();

        /*
         * Requests related to scripts.
         */
        bool saveScript(
                S9sString remoteFileName, 
                S9sString content);

        bool executeExternalScript(
                S9sString localFileName,
                S9sString content,
                S9sString arguments);

        bool executeScript(
                S9sString remoteFileName,
                S9sString arguments);

        bool removeScript(
                S9sString remoteFileName);

        bool treeScripts();

        /*
         * Requests related to the cmon users.
         */
        static S9sVariantMap 
            createUserRequest(
                    const S9sUser   &user,
                    const S9sString &newPassword,
                    bool             createGroup);

        bool getUsers();
        bool setUser();
        bool setPassword();

        bool getJobInstance(const int jobId);
        
        bool getJobLog(
                const int jobId,
                const int limit   = 0,
                const int offset  = 0);

        bool getLog();
        bool rollingRestart(const int clusterId);
        bool createReport(const int clusterId);

        bool createCluster();
        bool registerCluster();
        bool createNode();
        bool removeNode();
        bool stopCluster();
        bool startCluster();
        bool dropCluster();

        bool startNode();
        bool stopNode();
        bool restartNode();

        bool createMaintenance();

        bool createMaintenance(
                const S9sVariantList &hosts,
                const S9sString      &start,
                const S9sString      &end,
                const S9sString      &reason);

        bool createMaintenance(
                const int            &clusterId,
                const S9sString      &start,
                const S9sString      &end,
                const S9sString      &reason);

        bool deleteMaintenance();

        bool deleteMaintenance(
                const S9sString      &uuid);

        bool getMaintenance();

    protected:
        virtual bool
            executeRequest(
                const S9sString &uri,
                S9sVariantMap   &request);

        virtual bool 
            doExecuteRequest(
                const S9sString &uri,
                const S9sString &payload);

    private:
        // Low level methods that create/register new clusters.
        bool createGaleraCluster(
                const S9sVariantList &hosts,
                const S9sString      &osUserName,
                const S9sString      &vendor,
                const S9sString      &mySqlVersion,
                bool                  uninstall);

        bool registerGaleraCluster(
                const S9sVariantList &hosts,
                const S9sString      &osUserName);

        bool createMySqlReplication(
                const S9sVariantList &hosts,
                const S9sString      &osUserName,
                const S9sString      &vendor,
                const S9sString      &mySqlVersion,
                bool                  uninstall);
        
        bool registerMySqlReplication(
                const S9sVariantList &hosts,
                const S9sString      &osUserName);
        
        bool createGroupReplication(
                const S9sVariantList &hosts,
                const S9sString      &osUserName,
                const S9sString      &vendor,
                const S9sString      &mySqlVersion,
                bool                  uninstall);

        bool registerGroupReplication(
                const S9sVariantList &hosts,
                const S9sString      &osUserName);

        bool createNdbCluster(
                const S9sVariantList &mySqlHosts,
                const S9sVariantList &mgmdHosts,
                const S9sVariantList &ndbdHosts,
                const S9sString      &osUserName, 
                const S9sString      &vendor,
                const S9sString      &mySqlVersion,
                bool                  uninstall);
        
        bool registerNdbCluster(
                const S9sVariantList &mySqlHosts,
                const S9sVariantList &mgmdHosts,
                const S9sVariantList &ndbdHosts,
                const S9sString      &osUserName);

        bool createPostgreSql(
                const S9sVariantList &hosts,
                const S9sString      &osUserName,
                bool                  uninstall);

        bool registerPostgreSql(
                const S9sVariantList &hosts,
                const S9sString      &osUserName);
        
        // Low level methods that create/install a new node and add it to a
        // cluster.
        bool addNode(
                const int             clusterId,
                const S9sVariantList &hosts);
        
        bool addReplicationSlave(
                const int             clusterId,
                const S9sVariantList &hosts);

        bool addHaProxy(
                const int             clusterId,
                const S9sVariantList &hosts);
        
        bool addProxySql(
                const int             clusterId,
                const S9sVariantList &hosts);

        bool addMaxScale(
                const int             clusterId,
                const S9sVariantList &hosts);

        static S9sVariant 
            topologyField(
                const S9sVariantList &nodes);

        static S9sVariant
            nodesField(
                const S9sVariantList &nodes);
        
    private:
        S9sRpcClientPrivate *m_priv;

        friend class UtS9sRpcClient;
        friend class UtS9sNode;
};

