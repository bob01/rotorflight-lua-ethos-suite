--
--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local apiLoader = {}

-- Define the API directory path based on the ethos version
local apidir = "tasks/msp/api/"
local api_path = apidir


--[[
    Loads a Lua API module by its name, checks for the existence of the file, and wraps its functions.

    @param apiName (string) The name of the API to load.

    @return (table|nil) The loaded API module if successful, or nil if the file does not exist or is invalid.

    The function performs the following steps:
    1. Constructs the file path for the API module.
    2. Checks if the file exists using `rfsuite.utils.file_exists`.
    3. Loads the API module using `dofile`.
    4. Verifies that the module is a table and contains either a `read` or `write` function.
    5. Stores the API name inside the module as `__apiName`.
    6. Wraps the `read`, `write`, `setValue`, and `readValue` functions if they exist.
    7. Logs the successful loading of the API module.
    8. Returns the loaded API module.
    9. Logs an error if the file does not exist or the module is invalid.
--]]
local function loadAPI(apiName)

    local apiFilePath = api_path .. apiName .. ".lua"

    -- Check if file exists before trying to load it
    if rfsuite.utils.file_exists(apiFilePath) then
        local apiModule = dofile(apiFilePath) -- Load the Lua API file

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            -- Store the API name inside the module
            apiModule.__apiName = apiName

            -- Wrap the read function
            if apiModule.read then
                local originalRead = apiModule.read
                apiModule.read = function(...)
                    return originalRead(...)
                end
            end

            -- Wrap the write function
            if apiModule.write then
                local originalWrite = apiModule.write
                apiModule.write = function(...) 
                    return originalWrite(...)
                end
            end

            -- Wrap the setValue function
            if apiModule.setValue then
                local originalSetValue = apiModule.setValue
                apiModule.setValue = function(...)
                    return originalSetValue(...)
                end
            end

            -- Wrap the readValue function
            if apiModule.readValue then
                local originalReadValue = apiModule.readValue
                apiModule.readValue = function(...)
                    return originalReadValue(...)
                end
            end

            rfsuite.utils.log("Loaded API: " .. apiName, "debug")
            return apiModule
        else
            rfsuite.utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.", "debug")
        end
    else
        rfsuite.utils.log("Error: API file '" .. apiFilePath .. "' not found.", "debug")
    end
end



--[[
    Loads the specified API by name.
    
    @param apiName (string) - The name of the API to load.
    @return (table) - The loaded API table, or nil if the API could not be loaded.
]]
function apiLoader.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then
        rfsuite.utils.log("Unable to load " .. apiName,"debug")
    end
    return api
end


--[[
    Returns the size in bytes of the given data type.
    
    @param data_type (string): The data type to get the size of. 
                               Valid types are "U8", "U16", "U24", "U32", "S8", "S16", "S24", "S32".
    
    @return (number): The size in bytes of the given data type. Defaults to 1 if the data type is unknown.
]]
local function get_type_size(data_type)
    local type_sizes = {U8 = 1, U16 = 2, U24 = 3, U32 = 4, S8 = 1, S16 = 2, S24 = 3, S32 = 4}
    return type_sizes[data_type] or 1 -- Default to U8 if unknown
end


--[[
Parses MSP data from a buffer according to a given structure.

@param buf (string) The buffer containing the MSP data.
@param structure (table) The structure defining the data types and fields.
@param processed (table) Optional table to include in the returned data.
@param other (table) Optional table to include in the returned data.

@return (table) A table containing:
    - parsed: The parsed data as per the structure.
    - buffer: The original buffer.
    - structure: The original structure.
    - positionmap: A map of field names to their byte positions.
    - processed: The processed table if supplied.
    - other: The other table if supplied.
--]]
function apiLoader.parseMSPData(buf, structure, processed, other)
    local parsedData = {}
    buf.offset = 1  -- Centralize offset handling using mspHelper

    -- Map of sizes for known types
    local typeSizes = {
        U8 = 1, S8 = 1,
        U16 = 2, S16 = 2,
        U24 = 3, S24 = 3,
        U32 = 4, S32 = 4,
        U64 = 8, S64 = 8,  -- In case larger types are needed
    }

    local position_map = {}
    local current_byte = 1

    local apiVersion = rfsuite.session.apiVersion or 12.06

    for _, field in ipairs(structure) do
        if field.apiVersion and apiVersion < field.apiVersion then
            goto continue  -- Skip fields not supported by current API version
        end

        local byteorder = field.byteorder or "little"
        local size = typeSizes[field.type]
        if not size then
            rfsuite.utils.log("Error: Unknown data type: " .. field.type, "debug")
            return nil
        end

        -- Use mspHelper dynamic read
        local readFunction = rfsuite.tasks.msp.mspHelper["read" .. field.type]
        if not readFunction then
            rfsuite.utils.log("Error: No reader for type: " .. field.type, "debug")
            return nil
        end

        local data = readFunction(buf, byteorder)
        if data == nil then
            rfsuite.utils.log("Error reading field: " .. field.field .. " at offset " .. buf.offset, "debug")
        end
        parsedData[field.field] = data

        -- Build position map in the same loop
        local start_pos = current_byte
        local end_pos = start_pos + size - 1
        position_map[field.field] = {}

        if byteorder == "big" then
            for i = end_pos, start_pos, -1 do
                table.insert(position_map[field.field], i)
            end
        else
            for i = start_pos, end_pos do
                table.insert(position_map[field.field], i)
            end
        end

        current_byte = end_pos + 1

        ::continue::
    end

    -- Check for unused bytes in the buffer
    if buf.offset <= #buf then
        local extra_bytes = #buf - (buf.offset - 1)
        rfsuite.utils.log("Unused bytes in buffer (" .. extra_bytes .. " extra bytes)")
    elseif buf.offset > #buf + 1 then
        rfsuite.utils.log("Offset exceeded buffer length (Offset: " .. buf.offset .. ", Buffer: " .. #buf .. ")")
    end

    return {
        parsed = parsedData,
        buffer = buf,
        structure = structure,
        positionmap = position_map,
        processed = processed or nil,
        other = other or nil,
        receivedBytesCount = math.floor(buf.offset - 1)
    }
end

--[[
    Calculates the minimum number of bytes required for a given structure.

    @param structure (table): A table containing parameter definitions. Each parameter is a table with the following fields:
        - type (string): The data type of the parameter.
        - apiVersion (number, optional): The minimum API version required for this parameter.
        - mandatory (boolean, optional): Whether the parameter is mandatory. Defaults to true if not specified.

    @return (number): The total number of bytes required for the structure.
]]
function apiLoader.calculateMinBytes(structure)

    local apiVersion = rfsuite.session.apiVersion
    local totalBytes = 0

    for _, param in ipairs(structure) do
        local insert_param = false
    
        -- API version check logic
        if not param.apiVersion or (apiVersion and apiVersion >= param.apiVersion) then
            insert_param = true
        end
    
        -- Mandatory check
        if insert_param and (param.mandatory ~= false) then
            totalBytes = totalBytes + get_type_size(param.type)
        end
    end

    return totalBytes
end


--[[
    Filters a given structure based on the API version.

    @param structure (table): The structure to be filtered. Each element in the structure
                              should be a table that may contain an 'apiVersion' field.

    @return (table): A new table containing only the elements from the input structure
                     that meet the API version criteria.
]]
function apiLoader.filterByApiVersion(structure)

    local apiVersion = rfsuite.session.apiVersion or 12.06
    local filteredStructure = {}

    for _, param in ipairs(structure) do
        local insert_param = false

        -- API version check logic
        if not param.apiVersion or (apiVersion and rfsuite.utils.round(apiVersion,2) >= rfsuite.utils.round(param.apiVersion,2)) then
            insert_param = true
        end

        if insert_param then
            table.insert(filteredStructure, param)
        end
    end

    return filteredStructure
end

--[[
    Builds a simulated response based on the provided data structure.

    This function generates a response table for simulation purposes. It checks if the system is in simulation mode,
    and if so, it constructs the response based on the `simResponse` field of each element in the `dataStructure`.
    If `simResponse` is not provided for a field, it inserts default values based on the field's type size.

    @param dataStructure (table): A table containing the data structure with fields that may include `simResponse`.

    @return response (table or nil): A table containing the simulated response values, or nil if not in simulation mode.
]]
function apiLoader.buildSimResponse(dataStructure, apiName)

    if system:getVersion().simulation == false then
        return nil
    end

    -- Fallback to building from dataStructure if file is invalid or missing
    local response = {}

    for _, field in ipairs(dataStructure) do
        if field.simResponse then
            -- Append all values in simResponse to the response table
            for _, value in ipairs(field.simResponse) do
                table.insert(response, value)
            end
        else
            -- If simResponse is nil, insert default values based on the field's type size
            local type_size = get_type_size(field.type)
            for i = 1, type_size do
                table.insert(response, 0)
            end
        end
    end

    return response
end


--[[
    Creates a new instance of handlers for complete and error events.
    
    Functions:
    - setCompleteHandler(handlerFunction): Sets the custom complete handler. Expects a function as an argument.
    - setErrorHandler(handlerFunction): Sets the custom error handler. Expects a function as an argument.
    - getCompleteHandler(): Returns the current custom complete handler.
    - getErrorHandler(): Returns the current custom error handler.
    
    Returns:
    A table with the following functions:
    - setCompleteHandler
    - setErrorHandler
    - getCompleteHandler
    - getErrorHandler
]]
function apiLoader.createHandlers()
    -- Instance-specific storage
    local customCompleteHandler = nil
    local customErrorHandler = nil

    -- Function to set the Complete handler
    local function setCompleteHandler(handlerFunction)
        if type(handlerFunction) == "function" then
            customCompleteHandler = handlerFunction
        else
            error("setCompleteHandler expects a function")
        end
    end

    -- Function to set the Error handler
    local function setErrorHandler(handlerFunction)
        if type(handlerFunction) == "function" then
            customErrorHandler = handlerFunction
        else
            error("setErrorHandler expects a function")
        end
    end

    -- Function to get handlers safely
    local function getCompleteHandler()
        return customCompleteHandler
    end

    local function getErrorHandler()
        return customErrorHandler
    end

    -- Return an instance with functions that operate on separate data
    return {setCompleteHandler = setCompleteHandler, setErrorHandler = setErrorHandler, getCompleteHandler = getCompleteHandler, getErrorHandler = getErrorHandler}
end

--[[
    Builds the payload for writing to the API.

    @param apiname (string) - The name of the API.
    @param payload (table) - The data to be written.
    @param api_structure (table) - The structure of the API fields.

    @return (table) - The byte stream representing the payload.

    The function performs the following steps:
    1. Checks if delta updates can be used based on the presence of positionmap, receivedBytes, and receivedBytesCount.
    2. Logs whether delta updates or a full rebuild will be used.
    3. Precomputes a list of editable fields from formFields.
    4. Initializes the byte stream with the last known bytes if available.
    5. Defines a helper function to get the scale for a field from the page.
    6. Iterates over the API structure to process each field:
        - Skips non-editable fields.
        - Retrieves the value, byte order, and scale for the field.
        - Uses the appropriate write function based on the field type.
        - If delta updates are used and the field has a position map, patches the field into the byte stream.
        - Otherwise, performs a full write for the field.
    7. Returns the constructed byte stream.
--]]
function apiLoader.buildWritePayload(apiname, payload, api_structure)

    local positionmap = rfsuite.app.Page.mspapi and rfsuite.app.Page.mspapi.positionmap[apiname]
    local receivedBytes = rfsuite.app.Page.mspapi and rfsuite.app.Page.mspapi.receivedBytes[apiname]
    local receivedBytesCount = rfsuite.app.Page.mspapi and rfsuite.app.Page.mspapi.receivedBytesCount[apiname]

    local useDelta = positionmap and receivedBytes and receivedBytesCount

    if useDelta then
        rfsuite.utils.log("[buildWritePayload] Using delta updates for " .. apiname, "info")
    else
        rfsuite.utils.log("[buildWritePayload] No valid delta for " .. apiname .. ", doing full rebuild", "info")
    end

    -- Precompute list of editable fields from formFields
    local editableFields = {}
    for idx, formField in ipairs(rfsuite.app.formFields) do
        local pageField = rfsuite.app.Page.fields[idx]
        if pageField and pageField.apikey then
            editableFields[pageField.apikey] = true
        end
    end

    -- Start with a copy of the last known bytes
    local byte_stream = {}
    for i = 1, receivedBytesCount or 0 do
        byte_stream[i] = receivedBytes and receivedBytes[i] or 0
    end

    local function get_scale_from_page(field_name)
        if not rfsuite.app.Page.mspapi.api_reversed or not rfsuite.app.Page.fields then
            return 1
        end
        for _, v in ipairs(rfsuite.app.Page.fields) do
            if field_name == v.apikey and rfsuite.app.Page.mspapi.api_reversed[apiname] == v.mspapi then
                return v.scale
            end
        end
        return 1
    end

    for _, field_def in ipairs(api_structure) do
        local field_name = field_def.field

        -- Skip non-editable fields immediately
        if not editableFields[field_name] then
            rfsuite.utils.log("[buildWritePayload] Skipping non-editable field: " .. field_name, "debug")
            goto continue
        end

        local value = payload[field_name] or field_def.default or 0
        local byteorder = field_def.byteorder
        local scale = field_def.scale or get_scale_from_page(field_name) or 1
        value = math.floor(value * scale + 0.5)

        local writeFunction = rfsuite.tasks.msp.mspHelper["write" .. field_def.type]
        if not writeFunction then
            error("Unknown type: " .. tostring(field_def.type))
        end

        if useDelta and positionmap[field_name] then
            local field_positions = positionmap[field_name]
            local tmpStream = {}

            if byteorder then
                writeFunction(tmpStream, value, byteorder)
            else
                writeFunction(tmpStream, value)
            end

            for idx, pos in ipairs(field_positions) do
                if pos <= receivedBytesCount then
                    byte_stream[pos] = tmpStream[idx]
                end
            end

            rfsuite.utils.log(string.format(
                "[buildWritePayload] Patched field '%s' into positions [%s]",
                field_name, table.concat(field_positions, ",")
            ), "debug")

        else
            -- Full write fallback (non-patch mode)
            local tmpStream = {}
            if byteorder then
                writeFunction(tmpStream, value, byteorder)
            else
                writeFunction(tmpStream, value)
            end

            for i, byte in ipairs(tmpStream) do
                table.insert(byte_stream, byte)
            end

            rfsuite.utils.log(string.format(
                "[buildWritePayload] Full write for field '%s', no positionmap entry",
                field_name
            ), "info")
        end

        ::continue::
    end

    return byte_stream
end


-- New function to process structure in one pass
function apiLoader.prepareStructureData(structure)
    local filteredStructure = {}
    local minBytes = 0
    local simResponse = {}

    local apiVersion = rfsuite.session.apiVersion or 12.06

    for _, param in ipairs(structure) do
        if param.apiVersion and apiVersion < param.apiVersion then
            goto continue
        end

        table.insert(filteredStructure, param)

        if param.mandatory ~= false then
            minBytes = minBytes + get_type_size(param.type)
        end

        if param.simResponse then
            for _, value in ipairs(param.simResponse) do
                table.insert(simResponse, value)
            end
        else
            local typeSize = get_type_size(param.type)
            for i = 1, typeSize do
                table.insert(simResponse, 0)
            end
        end

        ::continue::
    end

    return filteredStructure, minBytes, simResponse
end

-- Backward compatible stubs
function apiLoader.filterByApiVersion(structure)
    local filtered, _, _ = apiLoader.prepareStructureData(structure)
    return filtered
end

function apiLoader.calculateMinBytes(structure)
    local _, minBytes, _ = apiLoader.prepareStructureData(structure)
    return minBytes
end

function apiLoader.buildSimResponse(structure)
    local _, _, simResponse = apiLoader.prepareStructureData(structure)
    return simResponse
end

return apiLoader
