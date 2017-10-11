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
#include "s9sserver.h"

//#define DEBUG
//#define WARNING
#include "s9sdebug.h"

S9sServer::S9sServer()
{
    m_properties["class_name"] = "CmonHost";
}

S9sServer::S9sServer(
        const S9sVariantMap &properties) :
    m_properties(properties)
{
    if (!m_properties.contains("class_name"))
        m_properties["class_name"] = "CmonHost";
}

S9sServer::~S9sServer()
{
}

S9sServer &
S9sServer::operator=(
        const S9sVariantMap &rhs)
{
    setProperties(rhs);
    
    return *this;
}

/**
 * \returns True if a property with the given key exists.
 */
bool
S9sServer::hasProperty(
        const S9sString &key) const
{
    return m_properties.contains(key);
}

/**
 * \returns The value of the property with the given name or the empty
 *   S9sVariant object if the property is not set.
 */
S9sVariant
S9sServer::property(
        const S9sString &name) const
{
    if (m_properties.contains(name))
        return m_properties.at(name);

    return S9sVariant();
}

/**
 * \param properties The properties to be set as a name -> value mapping.
 *
 * Sets all the properties in one step. All the existing properties will be
 * deleted, then the new properties set.
 */
void
S9sServer::setProperties(
        const S9sVariantMap &properties)
{
    m_properties = properties;
}

S9sString
S9sServer::hostName() const
{
    return property("hostname").toString();
}

S9sString
S9sServer::version() const
{
    return property("version").toString();
}

S9sString
S9sServer::ipAddress() const
{
    return property("ip").toString();
}

int
S9sServer::nContainers() const
{
    return property("containers").size();
}

S9sString
S9sServer::ownerName() const
{
    return property("owner_user_name").toString();
}

S9sString
S9sServer::groupName() const
{
    return property("owner_group_name").toString();
}