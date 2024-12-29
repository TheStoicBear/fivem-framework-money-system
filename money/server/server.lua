-- Ensure the resource name is correct
if (GetCurrentResourceName() ~= "money") then
    print("[^1DEBUG^0] Please make sure the resource name is ^3money^0 or else exports won't work.")
end

local accounts = {}

-- Function to add money
function addMoney(id, amount)
    if accounts[id] then
        accounts[id].amount = accounts[id].amount + amount
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
    end
end

-- Function to deduct money
function deductMoney(id, amount)
    if accounts[id] and accounts[id].amount >= amount then
        accounts[id].amount = accounts[id].amount - amount
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
        return true
    else
        return false -- Not enough money
    end
end

-- Function to deposit money into the bank
function depositMoney(id, amount)
    if accounts[id] and accounts[id].amount >= amount then
        accounts[id].amount = accounts[id].amount - amount
        accounts[id].bank = accounts[id].bank + amount
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
    else
        TriggerClientEvent('NAT2K15:BANKNOTIFY', id, "Insufficient cash to deposit.")
    end
end

-- Function to withdraw money from the bank
function withdrawMoney(id, amount)
    if accounts[id] and accounts[id].bank >= amount then
        accounts[id].bank = accounts[id].bank - amount
        accounts[id].amount = accounts[id].amount + amount
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
    else
        TriggerClientEvent('NAT2K15:BANKNOTIFY', id, "Insufficient funds in the bank.")
    end
end

-- Event to check or create account in the database
RegisterNetEvent('NAT2K15:CHECKSQL')
AddEventHandler('NAT2K15:CHECKSQL', function(steam, discord, first_name, last_name, dept)
    local src = source
    if accounts[src] then
        MySQL.Async.execute("UPDATE money SET bank = @bank, amount = @amount WHERE steam = @steam", {
            ["@bank"] = accounts[src].bank,
            ["@amount"] = accounts[src].amount,
            ["@steam"] = steam
        })
    end

    MySQL.Async.fetchAll("SELECT * FROM money WHERE steam = @steam", { ["@steam"] = steam }, function(data)
        if data[1] == nil then
            MySQL.Async.execute("INSERT INTO money (steam, discord, first, last, dept, bank, amount) VALUES (@steam, @discord, @first, @last, @dept, @bank, @amount)", {
                ["@steam"] = steam,
                ["@discord"] = discord,
                ["@first"] = first_name,
                ["@last"] = last_name,
                ["@dept"] = dept,
                ["@bank"] = config.starting_money,
                ["@amount"] = 0
            })
            accounts[src] = { steam = steam, discord = discord, bank = config.starting_money, amount = 0, dept = dept }
        else
            accounts[src] = { steam = steam, discord = discord, bank = tonumber(data[1].bank), amount = tonumber(data[1].amount), dept = dept }
        end
        TriggerClientEvent('NAT2K15:UPDATECLIENTMONEY', src, accounts[src])
    end)
end)

-- Save account data when a player leaves
AddEventHandler('playerDropped', function()
    local src = source
    if accounts[src] then
        MySQL.Async.execute("UPDATE money SET bank = @bank, amount = @amount WHERE steam = @steam", {
            ["@bank"] = accounts[src].bank,
            ["@amount"] = accounts[src].amount,
            ["@steam"] = accounts[src].steam
        })
        accounts[src] = nil
    end
end)

-- Pay salary periodically
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(config.cycle_length * 60 * 1000)
        for _, player in ipairs(GetPlayers()) do
            local src = tonumber(player)
            if accounts[src] and accounts[src].dept then
                accounts[src].bank = accounts[src].bank + config.deptPay[accounts[src].dept]
                TriggerClientEvent('NAT2K15:UPDATEPAY', src, accounts[src])
            end
        end
    end
end)

-- Exports for external usage
exports('addMoney', addMoney)
exports('deductMoney', deductMoney)
exports('depositMoney', depositMoney)
exports('withdrawMoney', withdrawMoney)

exports('getaccount', function(id)
    return accounts[id]
end)

exports('updateaccount', function(id, data)
    if accounts[id] then
        accounts[id].amount = data.amount
        accounts[id].bank = data.bank
        TriggerClientEvent('NAT2K15:UPDATEPAY', id, accounts[id])
    end
end)
