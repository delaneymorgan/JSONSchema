--[==[

JSONSchema

A simple JSON schema manager and JSON validator for Lua 5.1/5.2

Version 1.0

Manages schemas and validates objects against them. Also allows for creation
of fake objects based on schema values for use in tests.

See README for documentation, or better still check the test program for usage.

Copyright (C) 2021 Delaney & Morgan Computing
www.delaneymorgan.com.au

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]==]


local m_dkjson = require( "dkjson")


local JSONSchema = {}

JSONSchema.new = function( schemasPath)
    assert( schemasPath)
    self = {}
    self.schemas = {}
    self.schemasPath = schemasPath

    self._validateProperty = function( propertyName, propertyProperties, propertyInstance)
        local status = true
        local reason = nil
        if not propertyInstance then
            -- if there is no instance, no need to validate it.  Higher level checks for required fields
            return status, reason
        end
        if propertyProperties.enum then
            -- validate enum
            if not self._memberInArray( propertyProperties.enum, propertyInstance) then
                local errorMsg = string.format( "Error: %s - value \"%s\" not in enum [%s]", propertyName, propertyInstance, self._printArray( propertyProperties.enum))
                return false, {error=errorMsg, property=propertyName}
            end
        end
        if propertyProperties.type then
            if propertyProperties.type == "string" then
                if type( propertyInstance) ~= "string" then
                    local errorMsg = string.format( "Error: %s - value %s is not string", propertyName, tostring( propertyInstance))
                    return false, {error=errorMsg, property=propertyName}
                end
            elseif propertyProperties.type == "array" then
                local numElems = table.getn( propertyInstance)
                if numElems < propertyProperties.minItems then
                    local errorMsg = string.format( "Error: %s - %d elements in array (%d needed)", propertyName, numElems, propertyProperties.minItems)
                    return false, {error=errorMsg, property=propertyName}
                elseif numElems > propertyProperties.maxItems then
                    local errorMsg = string.format( "Error: %s - %d elements in array (%d allowed)", propertyName, numElems, propertyProperties.maxItems)
                    return false, {error=errorMsg, property=propertyName}
                end
                for _,instance in ipairs( propertyInstance) do
                    local status = false
                    local reason = nil
                    for _,property in ipairs( propertyProperties.items) do
                        status, reason = self._validateProperty( propertyName, property, instance)
                        if status then
                            break
                        end
                    end
                    if not status then
                        return status, reason
                    end
                end
            elseif (propertyProperties.type == "number") or (propertyProperties.type == "integer") then
                if type( propertyInstance) ~= "number" then
                    local errorMsg = string.format( "Error: %s - value \"%s\" is not a number", propertyName, tostring( propertyInstance))
                    return false, {error=errorMsg, property=propertyName}
                end
                if propertyProperties.minimum then
                    if propertyInstance < propertyProperties.minimum then
                        local errorMsg = string.format( "Error: %s - value %f is below minimum %f", propertyName, propertyInstance, propertyProperties.minimum)
                        return false, {error=errorMsg, property=propertyName}
                    end
                end
                if propertyProperties.maximum then
                    if propertyInstance > propertyProperties.maximum then
                        local errorMsg = string.format( "Error: %s - value %f is above maximum %f", propertyName, propertyInstance, propertyProperties.maximum)
                        return false, {error=errorMsg, property=propertyName}
                    end
                end
            end
        end
        return status, reason
    end

    self._validateLevel = function( schema, object)
        local levelProps = schema.properties
        local levelReqs = schema.required
        if not object then
            return true, nil
        end
        for propName,propProperties in pairs( levelProps) do
            if levelReqs and self._memberInArray( levelReqs, propName) then
                -- property is mandatory
                if object[propName] then
                    local status, reason = self._validateProperty( propName, propProperties, object[propName])
                    if not status then
                        return status, reason
                    end
                else
                    local errorMsg = string.format( "Error: %s missing, but required", propName)
                    local reason = {error=errorMsg, property=propName}
                    return false, reason
                end
            else
                local status, reason = self._validateProperty( propName, propProperties, object[propName])
                if not status then
                    return status, reason
                end
            end
            if propProperties.properties and object[propName] then
                -- if this is a table, drill down
                local status, reason = self._validateLevel( levelProps[propName], object[propName])
                if not status then
                    return status, reason
                end
            end
        end
        return true, nil
    end

    self.validate = function( schemaName, object)
        local schema = self.getSchema( schemaName)
        local status, reason = self._validateLevel( schema, object)
        return status, reason
    end

    self._fakeItem = function( itemProperties)
        if itemProperties.test_value then
            return itemProperties.test_value
        elseif itemProperties.enum then
            return itemProperties.enum[math.random( #itemProperties.enum)]
        elseif itemProperties.type == "string" then
            return "dummy_value"
        elseif itemProperties.type == "number" or itemProperties.type == "integer" then
            local num = 0
            if itemProperties.minimum and itemProperties.maximum then
                num = math.random( itemProperties.minimum, itemProperties.maximum)
            elseif itemProperties.minimum then
                num = itemProperties.minimum
            elseif itemProperties.maximum then
                num = itemProperties.maximum
            end
            if itemProperties.type == "integer" then
                num = (num >= 0) and math.floor( num + 0.5) or math.ceil( num - 0.5)
            end
            return num
        elseif type(itemProperties) == "table" then
            local property = itemProperties[math.random( #itemProperties)]
            return self._fakeItem( property)
        end
    end

    self._fakeLevel = function( schemaLevel)
        local levelProps = schemaLevel.properties
        local object = {}
        for propName,propProperties in pairs( levelProps) do
            if propProperties.type == "array" then
                object[propName] = {}
                -- TODO: handle heterogenous items
                for itemNo = 1,propProperties.maxItems do
                    object[propName][itemNo] = self._fakeItem( propProperties.items)
--                    object[propName][itemNo] = propProperties.items.enum[itemNo]
                end
            elseif propProperties.type == "object" then
                object[propName] = self._fakeLevel( levelProps[propName])
            elseif propProperties.test_value then
                object[propName] = self._fakeItem( propProperties)
            elseif propProperties.enum then
                object[propName] = self._fakeItem( propProperties)
            elseif propProperties.type == "string" then
                object[propName] = self._fakeItem( propProperties)
            elseif (propProperties.type == "number") or (propProperties.type == "integer") then
                object[propName] = self._fakeItem( propProperties)
            else
                object[propName] = propProperties
            end
        end
        return object
    end

    self.fakeObject = function( schemaName)
        local schema = self.getSchema( schemaName)
        local object = self._fakeLevel( schema)
        return object
    end
    
    self.load = function( filePath)
        local file = io.open( filePath)
        local data = file:read( '*all')
        io.close(file)
        local schema = m_dkjson.decode( data)
        return schema
    end

    self.getSchema = function( schemaName)
        if not self.schemas[schemaName] then
            self._loadSchema( schemaName)
        end
        return self.schemas[schemaName]
    end

    self._memberInArray = function( array, item)
        assert( array and (type( array) == "table"))
        assert( item)
        for _,value in ipairs( array) do
            if item == value then
                return true
            end
        end
        return false
    end
    
    self._printArray = function( array)
        local ret = ""
        if array then
            for index,value in ipairs( array) do
                if index ~= 1 then
                    ret = ret .. ", "
                end
                ret = ret .. value
            end
        end
        return ret
    end

    self._loadSchema = function( schemaName)
        self.schemas[schemaName] = self.load( self.schemasPath .. "/" .. schemaName)
    end

    return self
end

return JSONSchema
