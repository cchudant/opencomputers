local util = {}

--- Concatenate multiple arrays into a single array.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayEqual(util.arrayConcat({1, 2}, {3}), {1, 2, 3})))
--- assert(util.arrayEqual(util.arrayConcat({1, 2, 3}, {4, 5}, {6}), {1, 2, 3, 4, 5, 6}))
--- assert(util.arrayEqual(util.arrayConcat(), {}))
--- ```
---
--- @generic T
--- @param ... T[]
--- @return T[]
function util.arrayConcat(...)
    local newTable = {}
    for _, arr in ipairs({ ... }) do
        for _, el in ipairs(arr) do
            table.insert(newTable, el)
        end
    end
    return newTable
end

--- Check if a condition holds on every element of an array.
--- Returns true if the array is empty.
--- This is equivalent to util.arrayAny with the output and predicate both inverted.
--- The element index, and an instance of the array is also passed to the predicate in case you need it.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayAll({1, 2, 3}, function(el) return el > 2 end) == false)
--- ```
---
--- @generic T
--- @param arr T[]
--- @param predicate fun(t: T, i: number, arr: T[]): boolean
--- @return boolean
function util.arrayAll(arr, predicate)
    for i, el in ipairs(arr) do
        if not predicate(el, i, arr) then
            return false
        end
    end
    return true
end

--- Check if a condition holds on at least one element of an array.
--- Returns false if the array is empty.
--- This is equivalent to util.arrayAll with the output and predicate both inverted.
--- The element index, and an instance of the array is also passed to the predicate in case you need it.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayAny({1, 2, 3}, function(el) return el > 2 end) == true)
--- ```
---
--- @generic T
--- @param arr T[]
--- @param predicate fun(t: T, i: number, arr: T[]): boolean
--- @return boolean
function util.arrayAny(arr, predicate)
    for i, el in ipairs(arr) do
        if predicate(el, i, arr) then
            return true
        end
    end
    return false
end

--- Returns a copy of the given array, but that only contains elements matching the predicate.
--- The element index, and an instance of the array is also passed to the predicate in case you need it.
--- The input array is not modified.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayEqual(util.arrayFilter({1, 2, 3}, function(el) return el ~= 2 end), {1, 3}))
--- ```
---
--- @generic T
--- @param arr T[]
--- @param predicate fun(t: T, i: number, arr: T[]): boolean
--- @return T[]
function util.arrayFilter(arr, predicate)
    local newTable = {}
    for i, el in ipairs(arr) do
        if predicate(el, i, arr) then
            table.insert(newTable, el)
        end
    end
    return newTable
end

--- Find the first element in an array that satisfies the given predicate.
--- The element index, and an instance of the array is also passed to the predicate in case you need it.
--- Returns both the found element and index, or nil if none matched.
---
--- # Examples
---
--- ```lua
--- -- Find the first even element in an array
--- assert(util.arrayFind({1, 3, 7, 8, 11, 12}, function (el) return el % 2 == 0 end), 8)
--- ```
---
--- @generic T
--- @param arr T[]
--- @param predicate fun(t: T, i: number, arr: T[]): boolean
--- @return T? element
--- @return number? index
function util.arrayFind(arr, predicate)
    for i, el in ipairs(arr) do
        if predicate(el, i, arr) then
            return el, i
        end
    end
end

--- Find the last element in an array that satisfies the given predicate.
--- Searching is done in reverse order: this function will looking from the end and check every element until it
--- gets to the start.
--- The element index, and an instance of the array is also passed to the predicate in case you need it.
--- Returns both the found element and index, or nil if none matched.
---
--- # Examples
---
--- ```lua
--- -- Find the last even element in an array
--- assert(util.arrayFind({1, 3, 7, 8, 11, 12}, function (el) return el % 2 == 0 end), 12)
--- ```
---
--- @generic T
--- @param arr T[]
--- @param func fun(t: T, i: number, arr: T[]): boolean
--- @return T? element
--- @return number? index
function util.arrayFindLast(arr, func)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if func(el, i, arr) then
            return el, i
        end
    end
end

--- Construct a new array using the array's nested arrays elements.
--- This function will flatten recursively for `depth` amount of nesting, which defaults 1.
--- The input array is not modified.
---
--- # Examples
---
--- ```lua
--- -- Flatten once.
--- assert(util.arrayEqual(util.arrayFlat({{1}, {2, 3, 4}, {5}}), {1, 2, 3, 4, 5})
--- -- Flatten twice.
--- assert(util.arrayEqual(util.arrayFlat({{1}, {{2, 3}, 4}, {5}}, 2), {1, 2, 3, 4, 5})
--- ```
---
--- @generic T
--- @param arr T[][]
--- @param depth number? defaults to 1
--- @return T
function util.arrayFlat(arr, depth)
    local function arrFlat(newTable, arr, depth)
        if type(arr) == 'table' and depth > 0 then
            for i, el in ipairs(arr) do
                if not arrFlat(newTable, arr, depth - 1) then
                    table.insert(newTable, el)
                end
            end
            return true
        else
            return false
        end
    end
    local newTable = {}
    arrFlat(newTable, arr, depth or 1)
    return newTable
end

--- Construct an array composed of all of the items returned by `mappingFunc` applied to every element of the input array.
--- Contrary to `util.arrayMap`, this function appends multiple elements when `mappingFunc` returns an array.
--- This function also accepts an optional `depth` parameter, similar to `util.arrayFlat`.
--- The element index, and an instance of the array is also passed to the mapping function in case you need it.
--- The input array is not modified.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayEqual(util.arrayFlatMap({ 1, 2, 3 }, function (el)
---   local arr = {}
---   for i = 1, el do
---     table.insert(arr, i)
---   end
---   return arr
--- end), { 1, 1, 2, 1, 2, 3 }))
--- ```
---
--- @generic T
--- @generic U
--- @param arr T[]
--- @param mappingFunc fun(t: T, i: number, arr: T[]): U
--- @param depth number? defaults to 1
--- @return U[]
function util.arrayFlatMap(arr, mappingFunc, depth)
    local function arrFlat(newTable, arr, depth)
        if type(arr) == 'table' and depth > 0 then
            for i, el in ipairs(arr) do
                local elem = mappingFunc(el, i, arr)
                if not arrFlat(newTable, arr, depth - 1) then
                    table.insert(newTable, elem)
                end
            end
            return true
        else
            return false
        end
    end
    local newTable = {}
    arrFlat(newTable, arr, depth or 1)
    return newTable
end

--- Calls the given function for each element in the array.
--- The element index, and an instance of the array is also passed to the function in case you need it.
---
--- @generic T
--- @param arr T[]
--- @param func fun(t: T, i: number, arr: T[])
--- @return T[] arr
function util.arrayForEach(arr, func)
    for i, el in ipairs(arr) do
        func(el, i, arr)
    end
    return arr
end

--- Returns `true` if the given array contains the given `elem`.
--- This uses the standard lua `==` operator, if you need a special equality operator, use `util.arrayFind`.
---
--- @generic T
--- @param arr T[]
--- @return boolean
function util.arrayContains(arr, elem)
    for _, el in ipairs(arr) do
        if elem == el then
            return true
        end
    end
    return false
end

--- Returns the index of an element in a given array. This returns the first found equal element.
--- This uses the standard lua `==` operator, if you need a special equality operator, use `util.arrayFind`.
---
--- @generic T
--- @param arr T[]
--- @return number
function util.arrayIndexOf(arr, elem)
    for i, el in ipairs(arr) do
        if elem == el then
            return i
        end
    end
    return 0
end

--- Returns the last index of an element in a given array. This will check every element from last to first and return the index of the first one matching.
--- This uses the standard lua `==` operator, if you need a special equality operator, use `util.arrayFindLast`.
---
--- @generic T
--- @param arr T[]
--- @return number
function util.arrayLastIndexOf(arr, elem)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if elem == el then
            return i
        end
    end
    return 0
end

--- Concatenate an array into a string using a separator.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayJoin({1, 2, 3, 4, 5}, ' ') == '1 2 3 4 5')
--- ```
---
--- @generic T
--- @param arr T[]
--- @param separator string? defaults to ','
--- @return string
function util.arrayJoin(arr, separator)
    return table.concat(arr, separator or ",")
end

--- Returns a copy of the given array with every element mapped using `mappingFunc`.
--- The element index, and an instance of the array is also passed to the mapping function in case you need it.
--- The input array is not modified.
---
--- # Examples
---
--- ```lua
--- assert(util.arrayEqual(util.arrayMap({1, 2, 3}, function(el) return el * 2 end), {2, 4, 6}))
--- ```
---
--- @generic T
--- @generic U
--- @param arr T[]
--- @param mappingFunc fun(t: T, i: number, arr: T[]): U
--- @return U[]
function util.arrayMap(arr, mappingFunc)
    local newTable = {}
    for i, el in ipairs(arr) do
        local newEl = mappingFunc(el, i, arr)
        table.insert(newTable, newEl)
    end
    return newTable
end

--- Construct an array made out of the first `n` elements matching the given predicate.
---
--- @generic T
--- @param arr T[]
--- @param predicate fun(t: T, i: number, arr: T[]): boolean
--- @param n number
--- @return T[]
function util.arrayNFirsts(arr, predicate, n)
    local newTable = {}
    for i, el in ipairs(arr) do
        if predicate(el, i, arr) then
            table.insert(newTable, el)
        end
        if #newTable >= n then break end
    end
    return newTable
end

--- Returns the length of an array.
---
--- @generic T
--- @param arr T[]
--- @return number
function util.arrayLen(arr)
    return #arr
end

--- Reduces the elements into a single one, by repeatedly applying a reducer function.
--- For each element of the input array, the accumulator will be given to the reducer function as well as the array element.
--- This reducer function will return the new accumulator state that will be used for the next element.
--- The element index, and an instance of the array is also passed to the reducer in case you need it.
---
--- # Examples
---
--- ```lua
--- -- Compute the sum of every element in an array.
--- local initialAccumulator = 0
--- assert(util.arrayReduce({1, 11, 55}, function (acc, el)
---   return acc + el
--- end, initialAccumulator) == 67)
--- ```
---
--- @generic T
--- @generic Acc
--- @param arr T[]
--- @param reducer fun(accumulator: Acc, t: T, i: number, arr: T[]): Acc
--- @param accumulator Acc initial state
--- @return Acc accumulator final state
function util.arrayReduce(arr, reducer, accumulator)
    for i, v in ipairs(arr) do
        accumulator = reducer(accumulator, v, i, arr)
    end
    return accumulator
end

--- Same as `util.arrayReduce` but will apply the reducer from the last element to the first one.
---
--- @generic T
--- @generic Acc
--- @param arr T[]
--- @param func fun(accumulator: Acc, t: T, i: number, arr: T[]): Acc
--- @param accumulator Acc initial state
--- @return Acc accumulator final state
function util.arrayReduceRight(arr, func, accumulator)
    for i = #arr, 1, -1 do
        local v = arr[i]
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

--- Construct a new array that is the reverse of the given input array.
--- The input array is not modified.
---
--- @generic T
--- @param arr T[]
--- @return T[]
function util.arrayReverse(arr)
    local newTable = {}
    for i = #arr, 1, -1 do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

--- Returns a slice of the given array. This returns a new array containing every element from indices `start` to `end_` included.
--- The input array is not modified.
---
--- # Warning
---
--- Does not support negative indexes yet
---
--- @generic T
--- @param arr T[]
--- @param start number
--- @param end_ number?
--- @return T[]
function util.arraySlice(arr, start, end_)
    local newTable = {}
    table.move(arr, start, end_ or #arr, 1, newTable)
    return newTable
end

--- Returns a copy of an array.
---
--- @generic T
--- @param arr T[]
--- @return T[]
function util.arrayCopy(arr)
    return { table.unpack(arr) }
end

--- Remove every occurence of a given value from an array.
--- This uses the standard lua `==` operator, if you need a special equality operator, use `util.arrayRemoveIf`.
--- This modifies the input array in-place.
---
--- @generic T
--- @param arr T[]
--- @param value T
--- @return T[] arr
function util.arrayRemoveValue(arr, value)
    local i = 1
    while i <= #arr do
        local obj = arr[i]
        local toRemove = value == obj
        if toRemove then
            table.remove(arr, i)
        else
            i = i + 1
        end
    end
    return arr
end

--- Remove every item matching the given predicate from an array.
--- This modifies the input array in-place.
---
--- # Examples
---
--- ```lua
--- -- Remove every odd number from the array.
--- local arr = {1, 2, 4, 6, 7, 11}
--- util.arrayRemoveIf(arr, function (el) return el % 2 == 1 end)
--- assert(util.arrayEqual(arr, {2, 4, 6}))
--- ```
---
--- @generic T
--- @param arr T[]
--- @param predicate fun(t: T): boolean
--- @return T[] arr
function util.arrayRemoveIf(arr, predicate)
    local i = 1
    while i <= #arr do
        local obj = arr[i]
        local toRemove = predicate(obj)
        if toRemove then
            table.remove(arr, i)
        else
            i = i + 1
        end
    end
    return arr
end

--- Removes the last element of the given array, returning it.
--- Returns `nil` if the array was empty.
--- This modifies the input array in-place.
---
--- @generic T
--- @param arr T[]
--- @return T?
function util.arrayPop(arr)
    return table.remove(arr, #arr)
end

--- Adds elements to the end of an array.
--- This modifies the input array in-place.
---
--- @generic T
--- @param arr T[]
--- @param ... T elements
function util.arrayPush(arr, ...)
    for _, el in ipairs({ ... }) do
        table.insert(arr, el)
    end
end

--- Removes the first element of the given array, returning it.
--- Returns `nil` if the array was empty.
--- This modifies the input array in-place.
---
--- @generic T
--- @param arr T[]
--- @return T?
function util.arrayShift(arr)
    return table.remove(arr, 1)
end

--- Adds elements to the beginning of an array.
--- This modifies the input array in-place.
---
--- @generic T
--- @param arr T[]
--- @param ... T elements
--- @return T[]
function util.arrayUnshift(arr, ...)
    local items = table.pack(...)
    table.move(arr, items.n + 1, #arr, 1)
    table.move(items, 1, items.n, 1, arr)
    return arr
end

--- Adds elements to the beginning of an array.
--- This modifies the input array in-place.
---
--- @generic T
--- @param a T[]
--- @param b T[]
--- @return boolean
function util.arrayEqual(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

--- Removes duplicate elements of an array.
---
--- @generic T
--- @param arr T[]
--- @return T[]
function util.arrayUnique(arr)
    local res = {}
    local hash = {}
    for _, v in ipairs(arr) do
        if not hash[v] then
            table.insert(res, v)
            hash[v] = true
        end
    end
    return res
end

--- Returns the maximum element of an array, as well as its index.
--- This function uses the default '>' operator.
---
--- @generic T
--- @param arr T[]
--- @return number? max
--- @return number? index
function util.arrayMax(arr)
    local imax, max
    for i, v in ipairs(arr) do
        if v > (max or 0) then
            imax, max = i, v
        end
    end
    return max, imax
end

--- Returns an array containing every key of the given object.
--- The input object is not modified.
---
--- @generic T
--- @param obj { [T]: any }
--- @return T[]
function util.objectKeys(obj)
    local tab = {}
    for k, _ in pairs(obj) do
        table.insert(tab, k)
    end
    return tab
end

--- Returns the number of key, value pairs in the given object.
---
--- @param obj table
--- @return number
function util.objectCountEntries(obj)
    local total = 0
    for _, _ in pairs(obj) do
        total = total + 1
    end
    return total
end

--- Returns an array containing every value of the given object.
--- The input object is not modified.
---
--- @generic T
--- @param obj { [any]: T }
--- @return T[]
function util.objectValues(obj)
    local tab = {}
    for _, v in pairs(obj) do
        table.insert(tab, v)
    end
    return tab
end

--- Returns an array containing every key, value pairs of the given object.
--- The pairs are returned as a 2 element array.
--- The input object is not modified.
---
--- @generic K
--- @generic V
--- @param obj { [K]: V }
--- @return { [1]: K, [2]: V }[]
function util.objectEntries(obj)
    local tab = {}
    for k, v in pairs(obj) do
        table.insert(tab, { k, v })
    end
    return tab
end

--- Constructs an object from an array of key, value pairs. Each pair is represented by a 2 element array.
---
--- @generic K
--- @generic V
--- @param entries { [1]: K, [2]: V }[]
--- @return { [K]: V }
function util.objectFromEntries(entries)
    local obj = {}
    for _, v in ipairs(entries) do
        local k, el = table.unpack(v)
        obj[k] = el
    end
    return obj
end

--- Constructs an object composed of each key, value pair mapped via the `mappingFunc` applied to
--- each key, value pair of the input object.
--- The input object is not modified.
---
--- @generic K
--- @generic V
--- @generic NewK
--- @generic NewV
--- @param obj { [K]: V } object
--- @param mappingFunc fun(key: K, value: V): NewK, NewV
--- @return { [NewK]: NewV }
function util.objectMap(obj, mappingFunc)
    local newObj = {}
    for k, v in pairs(obj) do
        local newk, newv = mappingFunc(k, v)
        newObj[newk] = newv
    end
    return newObj
end

--- Copy an object.
---
--- @generic T: table
--- @param obj T
--- @return T
function util.objectCopy(obj)
    local newObj = {}
    for k, v in pairs(obj) do
        newObj[k] = v
    end
    return newObj
end

--- Checks if a condition holds on at least one key, value entry of an object.
--- Returns false if the object is empty.
--- This is equivalent to util.objectAll with the output and predicate both inverted.
---
--- @generic K
--- @generic V
--- @param obj { [K]: V }
--- @param predicate fun(key: K, value: V): boolean
--- @return boolean
function util.objectAny(obj, predicate)
    for k, v in pairs(obj) do
        if predicate(k, v) then
            return true
        end
    end
    return false
end

--- Checks if a condition holds all of the key, value entries of an object.
--- Returns true if the object is empty.
--- This is equivalent to util.objectAny with the output and predicate both inverted.
---
--- @generic K
--- @generic V
--- @param obj { [K]: V }
--- @param func fun(key: K, value: V): boolean
--- @return boolean
function util.objectAll(obj, func)
    for k, v in pairs(obj) do
        if not func(k, v) then
            return false
        end
    end
    return true
end

--- Finds the first key, value pair in an object that satisfies the given predicate.
--- Returns both the key and value found.
---
--- @generic K
--- @generic V
--- @param obj { [K]: V }
--- @param func fun(key: K, value: V): boolean
--- @return K? key
--- @return V? value
function util.objectFind(obj, func)
    for k, v in pairs(obj) do
        if func(k, v) then
            return k, v
        end
    end
end

--- Merge objects together, returning a single object containing the key, value pairs of each input
--- objects. If there are duplicate key, value pairs, only the last object's pair will be kept.
---
--- @generic K
--- @generic V
--- @param ... { [K]: V }
--- @return { [K]: V }
function util.objectMerge(...)
    local newObj = {}
    for _, obj in ipairs({ ... }) do
        for k, v in pairs(obj) do
            newObj[k] = v
        end
    end
    return newObj
end

--- Checks whether a string starts with a given prefix.
---
--- @param str string
--- @param prefix string
--- @return boolean
function util.stringStartsWith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

return util
