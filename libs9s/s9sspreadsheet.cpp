/*
 * Severalnines Tools
 * Copyright (C) 2018 Severalnines AB
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
#include "s9sspreadsheet.h"

//#define DEBUG
//#define WARNING
#include "s9sdebug.h"

S9sSpreadsheet::S9sSpreadsheet() :
    S9sObject(),
    m_screenRows(25),
    m_screenColumns(80),
    m_selectedCellRow(0),
    m_selectedCellColumn(0),
    m_firstVisibleRow(0),
    m_firstVisibleColumn(0),
    m_defaultColumnWidth(15)
{
    m_properties["class_name"] = "CmonSpreadsheet";
}
 
S9sSpreadsheet::S9sSpreadsheet(
        const S9sVariantMap &properties) :
    S9sObject(properties),
    m_screenRows(25),
    m_screenColumns(80),
    m_selectedCellRow(0),
    m_selectedCellColumn(0),
    m_firstVisibleRow(0),
    m_firstVisibleColumn(0),
    m_defaultColumnWidth(15)
{
    if (!m_properties.contains("class_name"))
        m_properties["class_name"] = "CmonSpreadsheet";
}

S9sSpreadsheet::~S9sSpreadsheet()
{
}

S9sSpreadsheet &
S9sSpreadsheet::operator=(
        const S9sVariantMap &rhs)
{
    setProperties(rhs);
    m_cells = property("cells").toVariantList();

    return *this;
}

S9sString
S9sSpreadsheet::warning() const
{
    S9sVariantList warnings = property("warnings").toVariantList();

    if (!warnings.empty())
        return warnings[0].toString();

    return S9sString();
}

void
S9sSpreadsheet::setScreenSize(
        uint columns, 
        uint rows)
{
    m_screenRows = rows;
    m_screenColumns = columns;
}

/**
 * \returns The index of the last row of the sheet that is visible.
 */
int
S9sSpreadsheet::lastVisibleRow() const
{
    return m_firstVisibleRow + m_screenRows - 1;
}

int
S9sSpreadsheet::lastVisibleColumn() const
{
    int   retval  = m_firstVisibleColumn;
    int   columns = columnWidth(retval);

    for (;;)
    {
        retval += 1;
        if (columns + columnWidth(retval) > (int)m_screenColumns - 5)
            break;

        columns += columnWidth(retval);
    }

    return retval;
}

int
S9sSpreadsheet::selectedCellRow() const
{
    return m_selectedCellRow;
}

int 
S9sSpreadsheet::selectedCellColumn() const
{
    return m_selectedCellColumn;
}

void
S9sSpreadsheet::selectedCellLeft()
{
    if (m_selectedCellColumn > 0)
        m_selectedCellColumn--;

    if (m_selectedCellColumn < m_firstVisibleColumn)
        m_firstVisibleColumn = m_selectedCellColumn;
}

void
S9sSpreadsheet::selectedCellRight()
{
    m_selectedCellColumn++;
    
    while (m_selectedCellColumn > lastVisibleColumn())
        m_firstVisibleColumn++;
}

void
S9sSpreadsheet::selectedCellUp()
{
    if (m_selectedCellRow > 0)
    {
        m_selectedCellRow--;

        if (m_selectedCellRow < m_firstVisibleRow)
            m_firstVisibleRow = m_selectedCellRow;
    }
}

void
S9sSpreadsheet::selectedCellDown()
{
    m_selectedCellRow++;

    if (m_selectedCellRow >= lastVisibleRow())
        m_firstVisibleRow = m_selectedCellRow - m_screenRows + 1;
}

void
S9sSpreadsheet::zoomIn()
{
    if (m_defaultColumnWidth < 32)
        ++m_defaultColumnWidth;
}

void
S9sSpreadsheet::zoomOut()
{
    if (m_defaultColumnWidth > 3)
        --m_defaultColumnWidth;
}

S9sString
S9sSpreadsheet::value(
        const uint sheet,
        const uint column,
        const uint row) const
{
    S9sVariantMap theCell = cell(sheet, column, row);

    return theCell["value"].toString();
}

S9sString
S9sSpreadsheet::contentString(
        const uint sheet,
        const uint column,
        const uint row) const
{
    S9sVariantMap theCell = cell(sheet, column, row);

    return theCell["contentString"].toString();
}

const char *
S9sSpreadsheet::cellBegin(
        const uint sheet,
        const uint column,
        const uint row) const
{
    if ((int)column == m_selectedCellColumn &&
            (int(row) == m_selectedCellRow))
    {
        return headerColorBegin();
    }

    return "";
}

const char *
S9sSpreadsheet::cellEnd(
        const uint sheet,
        const uint column,
        const uint row) const
{
    if ((int)column == m_selectedCellColumn &&
            (int(row) == m_selectedCellRow))
    {
        return headerColorEnd();
    }

    return "";
}

bool
S9sSpreadsheet::isAlignRight(
        const uint sheet,
        const uint column,
        const uint row) const
{
    S9sVariantMap theCell   = cell(sheet, column, row);
    S9sString     valueType = theCell["valuetype"].toString();

    if (valueType == "Double")
        return true;
    else if (valueType == "Int")
        return true;

    return false;
}


void
S9sSpreadsheet::print() const
{
    int thisColumn = 0;

    if (m_screenRows < 2u || m_screenColumns < 5u)
        return;

    /*
     * Printing the header line.
     */
    ::printf("     ");
    ::printf("%s", headerColorBegin());

    thisColumn = 5;
    for (uint col = m_firstVisibleColumn; col < 32; ++col)
    {
        int       theWidth  = columnWidth(col);
        int       nChars    = 0;
        S9sString label;

        if (thisColumn + theWidth > (int) m_screenColumns + 1)
            break;

        label += 'A' + col;
        
        for (uint n = 0; n < (theWidth - label.length()) / 2; ++n, ++nChars)
            ::printf(" ");

        ::printf("%s", STR(label));
        nChars += label.length();
        
        for (; nChars < theWidth; ++nChars)
            ::printf(" ");

        thisColumn += theWidth;
    }

    for (;thisColumn < (int)m_screenColumns;++thisColumn)
        ::printf(" ");

    //::printf("%s", TERM_ERASE_EOL);
    ::printf("%s", headerColorEnd());
    ::printf("\r\n");

    /*
     *
     */
    for (uint row = m_firstVisibleRow; row <= (uint)lastVisibleRow(); ++row)
    {
        ::printf("%s", headerColorBegin());
        ::printf(" %3u ", row + 1);
        ::printf("%s", headerColorEnd());

        for (uint col = m_firstVisibleColumn; col <= (uint)lastVisibleColumn(); ++col)
        {
            int       theWidth = columnWidth(col);
            S9sString theValue = value(0, col, row);

            if ((int)theValue.length() > theWidth)
                theValue.resize(theWidth);

            // 
            ::printf("%s", cellBegin(0, col, row));

            //
            // Printing the cell content.
            //
            if (!isAlignRight(0, col, row))
            {
                ::printf("%s", STR(theValue));
                if (theWidth > (int)theValue.length())
                {
                    for (uint n = 0; n < theWidth - theValue.length(); ++n)
                        ::printf(" ");
                }
            } else {
                if (theWidth > (int)theValue.length())
                {
                    for (uint n = 0; n < theWidth - theValue.length(); ++n)
                        ::printf(" ");
                }
                ::printf("%s", STR(theValue));
            }
            
            // 
            ::printf("%s", cellEnd(0, col, row));
        }
        
        ::printf("\r\n");
    }
}

int
S9sSpreadsheet::columnWidth(
        uint column) const
{
    return m_defaultColumnWidth;
}

S9sVariantMap
S9sSpreadsheet::cell(
        const uint sheet,
        const uint column,
        const uint row) const
{
    S9sVariantMap retval;

    if (m_cells.empty())
        m_cells = property("cells").toVariantList();

    for (uint idx = 0u; idx < m_cells.size(); ++idx)
    {
        S9sVariantMap theCell = m_cells[idx].toVariantMap();

        S9S_DEBUG("idx: %u", idx);
        if (theCell["sheetIndex"].toInt() != (int)sheet)
            continue;
        
        if (theCell["rowIndex"].toInt() != (int)row)
            continue;
        
        if (theCell["columnIndex"].toInt() != (int)column)
            continue;

        retval = theCell;
        break;
    }

    S9S_DEBUG("%u, %u, %u -> %s", 
            sheet, column, row,
            STR(retval.toString()));
    return retval;
}
        
const char *
S9sSpreadsheet::headerColorBegin() const
{
    return TERM_INVERSE;
}

const char *
S9sSpreadsheet::headerColorEnd() const
{
    return TERM_NORMAL;
}
