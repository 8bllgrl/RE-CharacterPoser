-- File: reframework/autorun/CharacterPoser/EMV_Utils.lua
local EMV_Utils = {}

-- Basic logging function to print values, based on logv from init.lua
function EMV_Utils.logv(value)
    local output_string = tostring(value)
    log.info(output_string)
    return output_string
end

-- Function to merge two tables. Useful for combining settings or data.
function EMV_Utils.merge_tables(table_a, table_b, no_overwrite)
    table_a = table_a or {}
    table_b = table_b or {}
    if no_overwrite then
        for key_b, value_b in pairs(table_b) do
            if table_a[key_b] == nil then
                table_a[key_b] = value_b
            end
        end
    else
        for key_b, value_b in pairs(table_b) do table_a[key_b] = value_b end
    end
    return table_a
end

-- Re-implementations of key functions from init.lua
local function split(str, separator)
	local t = {}
	for split_str in string.gmatch(str, "[^" .. separator .. "]+") do
		table.insert(t, split_str)
	end
	return t
end

function EMV_Utils.split(str, separator)
    return split(str, separator)
end

function EMV_Utils.vector_to_table(std_vector)
    local new_table = {}
    for i, element in ipairs(std_vector) do
        table.insert(new_table, element)
    end
    return new_table
end

-- New functions moved to the top
local function magnitude(vector)
    return math.sqrt(vector.x^2 + vector.y^2 + vector.z^2)
end

local function mat4_scale(mat)
	return Vector3f.new(magnitude(mat[0]), magnitude(mat[1]), magnitude(mat[2]))
end

function EMV_Utils.mat4_to_trs(mat4)
    local pos = mat4[3]:to_vec3()
    local rot = mat4:to_quat()
    local scale = mat4_scale(mat4)
    return pos, rot, scale
end

function EMV_Utils.trs_to_mat4(translation, rotation, scale)
    if type(translation) == "table" then
        translation, rotation, scale = table.unpack(translation)
    end
    local scale_mat = Matrix4x4f.new(
        Vector4f.new(scale.x or 1, 0, 0, 0),
        Vector4f.new(0, scale.y or 1, 0, 0),
        Vector4f.new(0, 0, scale.z or 1, 0),
        Vector4f.new(0, 0, 0, 1)
    )
    local new_mat = rotation:to_mat4() or Matrix4x4f.identity()
    new_mat = new_mat * scale_mat
    new_mat[3] = ((translation and translation.to_vec4 and translation:to_vec4()) or translation) or new_mat[3]
    return new_mat
end

function EMV_Utils.get_trs(object)
    return object:call("get_Position"), object:call("get_Rotation"), object:call("get_LocalScale")
end

function EMV_Utils.clone(instance, instance_type)
    if sdk.is_managed_object(instance) then
        instance_type = instance_type or instance:get_type_definition()
        local i_name = instance_type:get_full_name()
        local worked, copy = pcall(sdk.create_instance, instance_type:get_full_name())

        if not worked then
            copy = ValueType.new(instance_type)
        end

        if copy then
            copy:call(".cctor")
            copy:call(".ctor")
        end

        copy = copy or instance:call("MemberwiseClone")

        if copy and sdk.is_managed_object(copy) then
            if tostring(instance):find("SystemArray") then
                local elements = instance:get_elements()
                for i, elem in ipairs(elements) do
                    local new_element = EMV_Utils.clone(elem)
                    copy:call("set_Item", i, new_element)
                end
            else
                for i, field in ipairs(instance_type:get_fields()) do
                    local field_name = field:get_name()
                    local field_type = field:get_type()
                    if not field:is_literal() then
                        local new_field = instance:get_field(field_name)
                        if new_field ~= nil and type(new_field) ~= "string" then
                            if sdk.is_managed_object(new_field) and not field_type:is_a("via.Component") and not field_type:is_a("via.GameObject") then
                                new_field = EMV_Utils.clone(new_field)
                            end
                            sdk.set_native_field(copy, instance_type, field_name, new_field)
                        end
                    end
                end
            end
            return copy:add_ref()
        end
    end
    return instance
end

local function can_index(lua_object)
	local mt = getmetatable(lua_object)
	return (not mt and type(lua_object) == "table") or (mt and (not not mt.__index))
end

function EMV_Utils.is_valid_obj(obj, is_not_vt)
	if type(obj)=="userdata" then
		if (not is_not_vt and tostring(obj):find("::ValueType")) then
			return true
		end
		return sdk.is_managed_object(obj) and can_index(obj)
	end
end

-- New function to find the index of a value in an array
function EMV_Utils.find_index(tbl, value)
	for i, item in ipairs(tbl) do
		if item == value then
			return i
		end
	end
end

return EMV_Utils