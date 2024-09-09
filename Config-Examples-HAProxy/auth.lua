local passwords = {
    ["YOUR-TROJAN-PASSWORD-HASH"] = true			-- Run this command to hash your password: echo -n "YOUR-TROJAN-PASSWORD" | openssl dgst -sha224 | sed 's/.* //'
}

function trojan_auth(txn)
    local status, data = pcall(function() return txn.req:dup() end)
    if status and data then
        -- Uncomment to enable logging of all received data
        -- core.Info("Received data from client: " .. data)
        local sniffed_password = string.sub(data, 1, 56)
        -- Uncomment to enable logging of sniffed password hashes
        -- core.Info("Sniffed password: " .. sniffed_password)
        if passwords[sniffed_password] then
            return "trojan"
        end
    end
    return "http"
end

core.register_fetches("trojan_auth", trojan_auth)
