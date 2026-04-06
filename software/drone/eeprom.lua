local loaded = {
    _G = _G,
    coroutine = coroutine,
    math = math,
    package = package,
    string = string,
    table = table
}
function require(module)
    if loaded[module] ~= nil then
        return loaded[module]
    end
    error(string.format("module '%s' not found", module))
end

--[[ // include libs // ]]--
