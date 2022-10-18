local rpc = require("vuci.rpc")
local json = require("cjson")
local socket = require("socket")

function sleep(sec)
    socket.select(nil, nil, sec)
end

ResultsFile = "/tmp/speedtest_results"
MaxTries = 10
local serversListFile = "/tmp/server_list"

local M = {}

function M.download(params)
    if not params or not params.host then
        return { status = "failed", error = "Host name was not provided" }
    end

    io.popen("speedtest -d "..params.host)
    return { status = "done" }
end

function M.upload(params)
    if not params or not params.host then
        return { status = "failed", error = "Host name was not provided" }
    end

    io.popen("speedtest -u "..params.host)
    return { status = "done" }
end

function M.readResults()
    local file, err = io.open(ResultsFile, "r")
    if not file then
        return { status = "failed", error = err }
    end

    local tries = 0
    while tries < MaxTries do
        local data = file:read("*a")
        if string.len(data) > 0 then
            file:close()
            local d = json.decode(data)
            d.tries = tries
            return d
        end
        sleep(0.02)
        tries = tries + 1
    end
    return { status = "failed", message = "Maximum amount of tries exceeded: "..tries }
end

function M.getServerList()
    os.execute("speedtest -s")
    local file, err = io.open(serversListFile, "r")
    if not file then
        return { status = "failed", error = err }
    end

    local servers = file:read("*a")
    if servers then
        return json.decode(servers)
        -- return { status = "done", servers = servers }
    else
        return { status = "failed", error = "Failed to retreive server list" }
    end
end

function M.getIpInfo()
    local handle = io.popen("speedtest -i")
    return json.decode(handle:read("*a"))
end

function M.findBestServer()
    io.popen("speedtest -b")
    return { status = "done" }
end

function M.getBestServer()
    local file, err = io.open(ResultsFile, "r")
    if not file then
        error(err)
    end
    return json.decode(file:read("*a"))
end

function M.alive(params)
    if not params or not params.host then
        return { status = "failed", error = "Host name was not provided" }
    end

    local handle = io.popen('speedtest -a '..params.host)
    return json.decode(handle:read('*a'))
end

return M
