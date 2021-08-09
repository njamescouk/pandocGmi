-- This is a gross hack of the sample custom writer for pandoc.
-- It produces output
-- that is very similar to that of pandoc's HTML writer.
-- There is one new feature: code blocks marked with class 'dot'
-- are piped through graphviz and images are included in the HTML
-- output using 'data:' URLs. The image format can be controlled
-- via the `image_format` metadata field.
--
-- Invoke with: pandoc -t gmi.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua sample.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

local pipe = pandoc.pipe
local stringify = (require "pandoc.utils").stringify

-- The global variable PANDOC_DOCUMENT contains the full AST of
-- the document which is going to be written. It can be used to
-- configure the writer.
local meta = PANDOC_DOCUMENT.meta

-- Choose the image format based on the value of the
-- `image_format` meta value.
local image_format = meta.image_format and stringify(meta.image_format) or "png"
local image_mime_type =
    ({
    jpeg = "image/jpeg",
    jpg = "image/jpeg",
    gif = "image/gif",
    png = "image/png",
    svg = "image/svg+xml"
})[image_format] or error("unsupported image format `" .. image_format .. "`")

-- Character escaping
local function escape(s, in_attribute)
    return s:gsub(
        '[<>&"\']',
        function(x)
            if x == "<" then
                return "&lt;"
            elseif x == ">" then
                return "&gt;"
            elseif x == "&" then
                return "&amp;"
            elseif in_attribute and x == '"' then
                return "&quot;"
            elseif in_attribute and x == "'" then
                return "&#39;"
            else
                return x
            end
        end
    )
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
    local attr_table = {}
    for x, y in pairs(attr) do
        if y and y ~= "" then
            table.insert(attr_table, " " .. x .. '="' .. escape(y, true) .. '"')
        end
    end
    return table.concat(attr_table)
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}
local links = {}

-- Blocksep is used to separate block elements.
function Blocksep()
    return "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will do the template processing as usual.
function Doc(body, metadata, variables)
    local buffer = {}
    local function add(s)
        table.insert(buffer, s)
    end
    add(body)
    if #notes > 0 then
        add("### footnotes")
        for _, note in pairs(notes) do
            add(note)
        end
    end

    if #links > 0 then
        add("### links")
        for _, link in pairs(links) do
            add(link)
        end
    end
    return table.concat(buffer, "\n") .. "\n"
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
    return s
end

function Space()
    return " "
end

function SoftBreak()
    return " "
end

function LineBreak()
    return "\n"
end

function Emph(s)
    return "/" .. s .. "/"
end

function Strong(s)
    return "*" .. s .. "*"
end

function Subscript(s)
    return "_" .. s
end

function Superscript(s)
    return "^" .. s
end

function SmallCaps(s)
    return '<span style="font-variant: small-caps;">' .. s .. "</span>"
end

function Strikeout(s)
    return " --- " .. s .. " --- "
end

function Link(s, tgt, tit, attr)
    local text = s
    local textIsLink = false
    if string.find(s, "=>", 1, true) ~= nil then
        textIsLink = true
        s = string.sub(s, 2)
    end
    if not string.len(tit) == 0 then
        text = s .. "(" .. tit .. ")"
    end
    local num = #links + 1
    -- add link to the link table.
    table.insert(links, "=> " .. escape(tgt, true) .. " [" .. num .. "] " .. text)
    -- return the link text and ref number.
    -- sthing not quite right here
    if textIsLink then
        return text .. " [" .. num .. "]"
    end

    return "<" .. text .. "> [" .. num .. "]"
end

function Image(s, src, tit, attr)
    return "=> " .. src .. " " .. tit .. "\n"
end

function Code(s, attr)
    return "`" .. s .. "`"
end

function InlineMath(s)
    return "$" .. s .. "$"
end

function DisplayMath(s)
    return "$" .. s + "\n$\n"
    --return "\\[" .. escape(s) .. "\\]"
end

function SingleQuoted(s)
    return '"' .. s .. '"'
end

function DoubleQuoted(s)
    return "'" .. s .. "'"
end

function Note(s)
    local num = #notes + 1
    -- insert the back reference right before the final closing tag.

    -- add note to the note table.
    table.insert(notes, "[" .. num .. "] " .. s)
    -- return the footnote reference, linked to the note.
    return "[fn " .. num .. "]"
end

function Span(s, attr)
    return s
end

function RawInline(format, str)
    if format == "html" then
        return str
    else
        return ""
    end
end

function Cite(s, cs)
    return "\nsorry cite not implemented\n"
end

function Plain(s)
    return s
end

function Para(s)
    return s .. "\n"
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
    if lev == 1 then
        return "# " .. s .. "\n"
    elseif lev == 2 then
        return "## " .. s .. "\n"
    elseif lev == 3 then
        return "### " .. s .. "\n"
    else
        return s .. "\n"
    end
end

function BlockQuote(s)
    return "> " .. s .. "\n"
end

function HorizontalRule()
    return "```\n----------------------------------------------------------- <hr>\n```\n"
end

function LineBlock(ls)
    return "LineBlock not implemented"
    --return '<div style="white-space: pre-line;">' .. table.concat(ls, '\n') .. '</div>'
end

function CodeBlock(s, attr)
    return "```\n" .. s .. "\n```"
end

function BulletList(items)
    local buffer = {}
    for _, item in pairs(items) do
        table.insert(buffer, "* " .. item)
    end
    return table.concat(buffer, "\n")
end

function OrderedList(items)
    local buffer = {}
    for _, item in pairs(items) do
        table.insert(buffer, "* " .. item)
    end
    return table.concat(buffer, "\n")
end

function DefinitionList(items)
    local buffer = {}
    for _, item in pairs(items) do
        local k, v = next(item)
        table.insert(buffer, "### " .. k .. "\n" .. table.concat(v, "\n"))
    end
    return table.concat(buffer, "\n")
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
local function html_align(align)
    if align == "AlignLeft" then
        return "left"
    elseif align == "AlignRight" then
        return "right"
    elseif align == "AlignCenter" then
        return "center"
    else
        return "left"
    end
end

function CaptionedImage(src, tit, caption, attr)
    return '<div class="figure">\n<img src="' ..
        escape(src, true) ..
            '" title="' .. escape(tit, true) .. '"/>\n' .. '<p class="caption">' .. escape(caption) .. "</p>\n</div>"
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
    -- finding out more about lua than I wanted to here...
    local function dQuote(value)
        if value == nil then
            return nil
        end
        return '"' .. value .. '"'
    end

    -- accumulate table csv in string res
    local res = "```" .. caption .. "\n"
    -- get the top line
    for i, col in pairs(headers) do
        if i > 1 then
            res = res .. ","
        end
        res = res .. dQuote(col)
    end
    res = res .. "\n"

    -- get the rest of the table
    for i, curRow in pairs(rows) do
        for i, col in pairs(curRow) do
            if i > 1 then
                res = res .. ","
            end
            res = res .. dQuote(col)
        end
        res = res .. "\n"
    end
    res = res .. "``` "
    
    -- send it to pandoc
    return res
end

function RawBlock(format, str)
    if format == "html" then
        return str
    else
        return ""
    end
end

function Div(s, attr)
    return s
    --return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index = function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n", key))
    return function()
        return ""
    end
end
setmetatable(_G, meta)
