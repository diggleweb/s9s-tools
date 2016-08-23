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
#include "ut_s9sstring.h"

#include <libs9s/library.h>
#include <cstdio>
#include <cstring>

//#define DEBUG
#include "s9sdebug.h"

UtS9sString::UtS9sString()
{
    S9S_DEBUG("");
}

UtS9sString::~UtS9sString()
{
}

bool
UtS9sString::runTest(const char *testName)
{
    bool retval = true;

    S9S_DEBUG(" *** running test: %s\n", testName ? testName: "all");
    PERFORM_TEST(test01, retval);

    return retval;
}

bool
UtS9sString::test01()
{
    return true;
}

CMON_UNIT_TEST_MAIN(UtS9sString)

