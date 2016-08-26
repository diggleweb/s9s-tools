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
 * Foobar is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Foobar. If not, see <http://www.gnu.org/licenses/>.
 */
#pragma once

#include "S9sString"
#include "S9sVariant"
#include "S9sVariantMap"

/**
 * Singleton class to handle s9s command line options.
 */
class S9sOptions
{
    public:
        static S9sOptions *instance();

        bool readOptions(int *argc, char *argv[]);

        int exitStatus() const;

    private:
        S9sOptions();
        ~S9sOptions();
        
        static S9sOptions *sm_instance;

    private:
        int                m_exitStatus;
};
