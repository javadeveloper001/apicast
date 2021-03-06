local resty_url = require('resty.url')

local setmetatable = setmetatable

local _M = {

}
local mt = { __index = _M }

local allowed_schemes = {
    file = true,
    -- TODO: support Data URI
}


function _M.new(uri)
    local url, err = resty_url.parse(uri)

    if not url then return nil, err end

    if not allowed_schemes[url.scheme] then
        return nil, 'scheme not supported'
    end

    return setmetatable({ url = url }, mt)
end

do
    local loaders = { }
    local pcall = pcall
    local path = require('pl.path')
    local file = require('pl.file')

    local YAML = require('lyaml')
    local cjson = require('cjson')

    local decoders = {
        ['.yml'] = YAML.load,
        ['.yaml'] = YAML.load,
        ['.json'] = cjson.decode,
    }

    local function decode(fmt, contents)
        local decoder = decoders[fmt]

        if not decoder then return nil, 'unsupported format' end

        local ok, ret = pcall(decoder, contents)

        if ok then
            return ret
        else
            return false, ret
        end
    end

    function loaders.file(uri)
        local filename = uri.opaque or ('%s%s'):format(uri.host, uri.path)
        if not filename then return nil, 'invalid file url' end

        local ext = path.extension(filename)
        local contents = file.read(filename)

        if contents then
            return decode(ext, contents)
        else
            return nil, 'no such file'
        end
    end

    function _M:load()
        local url = self and self.url
        if not url then return nil, 'not initialized' end

        local load = loaders[url.scheme]
        if not load then return nil, 'cannot load scheme' end


        return load(url)
    end
end

return _M
