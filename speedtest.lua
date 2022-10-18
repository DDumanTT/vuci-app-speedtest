#! /usr/bin/env lua

json = require("cjson")
curl = require("cURL")
socket = require("socket")

ResultsFile = "/tmp/speedtest_results"
ServersListFile = "/tmp/server_list"
ServersList = "https://raw.githubusercontent.com/DDumanTT/lua_speedtest/main/servers.json"
UserAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36"

Status = {
    RUNNING  = "running",
    FINISHED = "finished",
    FAILED   = "failed"
}

t = nil

function ProgressFunctionDown(totalDown, downloaded, _, _)
    local result = { status = Status.RUNNING, speed = 0 }
    local down_speed_exact = downloaded / 1000000 / (socket.gettime() - t)
    local down_speed = tonumber(string.format("%.2f", down_speed_exact * 8)) -- conversion to bits
    
    result.speed = down_speed
    result.time = socket.gettime() - t
    local file = io.open(ResultsFile, "w")
    file:write(json.encode(result))
    file:close()
end

function ProgressFunctionUp(_, _, totalUp, uploaded)
    local result = { status = Status.RUNNING, speed = 0 }
    local up_speed_exact = uploaded / 1000000 / (socket.gettime() - t)
    local up_speed = tonumber(string.format("%.2f", up_speed_exact * 8))

    result.speed = up_speed
    local file = io.open(ResultsFile, "w")
    file:write(json.encode(result))
    file:close()
end

function DownloadTest(host)
    t = socket.gettime()
    local e = curl.easy({
        url = host .. "/download",
        accept_encoding = "gzip, deflate, br",
        useragent = UserAgent,
        writefunction = function() end,
        progressfunction = ProgressFunctionDown,
        noprogress = false,
        timeout = 15
    })
    local status, err = pcall(e.perform, e)

    local handle, err = io.open(ResultsFile, "r")
    if not handle then
        error(err)
    end

    local result = json.decode(handle:read("*a"))
    handle:close()

    local handle, err = io.open(ResultsFile, "w")
    if not handle then
        error(err)
    end
    result.status = Status.FINISHED
    handle:write(json.encode(result))
    handle:close()
end

function UploadTest(host)
    local zero, err = io.open("/dev/zero", "r")
    if not zero then
        error(err)
    end

    t = socket.gettime()
    local e = curl.easy({
        url = host .. "/upload",
        accept_encoding = "gzip, deflate, br",
        useragent = UserAgent,
        post = true,
        httppost = curl.form({
            file = {
                file = "/dev/zero",
                type = "text/plain",
                name = "zeros"
            }
        }),
        writefunction = function() end,
        readfunction = zero,
        progressfunction = ProgressFunctionUp,
        noprogress = false,
        timeout = 15
    })
    local status, err = pcall(e.perform, e)
    zero:close()

    local handle, err = io.open(ResultsFile, "r")
    if not handle then
        error(err)
    end

    local result = json.decode(handle:read("*a"))
    handle:close()

    local handle, err = io.open(ResultsFile, "w")
    if not handle then
        error(err)
    end
    result.status = Status.FINISHED
    handle:write(json.encode(result))
    handle:close()
end

function GetIpInfo()
    local output
    local e = curl.easy({
        url = "http://ip-api.com/json/",
        useragent = UserAgent,
        writefunction = function(str) output = str end
    })

    local status, err = pcall(e.perform, e)
    if not status then
        error(err)
    end
    return output
end

function GetServersList()
    local handle = io.open(ServersListFile, "r")
    if not handle then
        local file, err = io.open(ServersListFile, "w")
        if not file then
            error(err)
        end
        local e = curl.easy({
            url = ServersList,
            useragent = UserAgent,
            writefunction = file
        })
        local status, err = pcall(e.perform, e)
        if not status then
            error(err)
        end
        file:close()
    else
        handle:close()
    end
end

function FindBestServer()
    local file, err = io.open(ResultsFile, "w")
    if not file then
        error(err)
    end
    file:write(json.encode({ status = Status.RUNNING }))
    file:close()

    GetServersList()
    local file, err = io.open(ServersListFile, "r")
    if not file then
        error(err)
    end
    local servers = json.decode(file:read("*a"))
    local country = json.decode(GetIpInfo()).country

    local best = 999999
    local best_server
    for i, server in ipairs(servers) do
        if server.Country == country then
            local e = curl.easy({
                url = server.Host.."/hello",
                useragent = UserAgent,
                nobody = true,
                followlocation = true,
                timeout = 1
            })
            local status, err = pcall(e.perform, e)
            if status then
                local time = e:getinfo_total_time()
                print(time)
                if time < best then
                    best = time
                    best_server = server
                end
            end
            e:close()
        end
    end
    local file, err = io.open(ResultsFile, "w")
    if not file then
        error(err)
    end

    file:write(json.encode({ status = Status.FINISHED, server = best_server })):close()
end

function AliveTest(host)
    local e = curl.easy({
        url = host .. "/hello",
        useragent = UserAgent,
        writefunction = function() end,
        timeout = 3
    })
    
    local status, err = pcall(e.perform, e)
    if status then
        return json.encode({ status = Status.FINISHED })
    end
    return json.encode({ status = Status.FAILED, error = err })
end

function main()
    local argparse = require("argparse")

    local parser = argparse()
    parser:mutex(
        parser:option("-d --download"):argname("<host>"),
        parser:option("-u --upload"):argname("<host>"),
        parser:option("-a --alive"):argname("<host>"),
        parser:flag("-i --ip"),
        parser:flag("-s --servers_list"),
        parser:flag("-b --best_server")
    )
    local args = parser:parse()

    if args.download then
        DownloadTest(args.download)
    elseif args.upload then
        UploadTest(args.upload)
    elseif args.alive then
        io.stdout:write(AliveTest(args.alive))
    elseif args.ip then
        io.stdout:write(GetIpInfo())
    elseif args.servers_list then
        GetServersList()
    elseif args.best_server then
        FindBestServer()
    end
end

main()
