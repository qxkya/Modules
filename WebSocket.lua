local WebSocketModule = {}
WebSocketModule.__index = WebSocketModule

local CONNECTING = 0
local OPEN = 1
local CLOSING = 2
local CLOSED = 3

function WebSocketModule.new(url)
    local self = setmetatable({}, WebSocketModule)
    
    self.url = url
    self.readyState = CLOSED
    self.connection = nil
    self.callbacks = {
        onOpen = nil,
        onMessage = nil,
        onClose = nil,
        onError = nil
    }
    
    return self
end

function WebSocketModule:Connect()
    if self.readyState ~= CLOSED then
        warn("WebSocket is already connected or connecting")
        return false
    end
    
    self.readyState = CONNECTING
    
    local success, connection = pcall(function()
        return WebSocket.connect(self.url)
    end)
    
    if not success then
        self.readyState = CLOSED
        if self.callbacks.onError then
            self.callbacks.onError("Failed to create WebSocket connection: " .. tostring(connection))
        end
        return false
    end
    
    self.connection = connection
    self.readyState = OPEN
    
    if self.connection then
        self.connection.OnMessage:Connect(function(message)
            if self.callbacks.onMessage then
                self.callbacks.onMessage(message)
            end
        end)
        
        self.connection.OnClose:Connect(function()
            self.readyState = CLOSED
            if self.callbacks.onClose then
                self.callbacks.onClose()
            end
        end)
    end
    
    if self.callbacks.onOpen then
        self.callbacks.onOpen()
    end
    
    return true
end

function WebSocketModule:Send(data)
    if self.readyState ~= OPEN then
        warn("WebSocket is not open")
        return false
    end
    
    if not self.connection then
        warn("No WebSocket connection")
        return false
    end
    
    local message
    if type(data) == "table" then
        message = game:GetService("HttpService"):JSONEncode(data)
    else
        message = tostring(data)
    end
    
    local success, result = pcall(function()
        return self.connection:Send(message)
    end)
    
    if not success then
        warn("Failed to send message: " .. tostring(result))
        return false
    end
    
    return true
end

function WebSocketModule:Disconnect()
    if self.readyState == CLOSED then
        return
    end
    
    self.readyState = CLOSING
    
    if self.connection then
        local success, result = pcall(function()
            return self.connection:Close()
        end)
        
        if not success then
            warn("Failed to close connection: " .. tostring(result))
        end
    end
    
    self.readyState = CLOSED
    self.connection = nil
end

function WebSocketModule:OnOpen(callback)
    self.callbacks.onOpen = callback
end

function WebSocketModule:OnMessage(callback)
    self.callbacks.onMessage = callback
end

function WebSocketModule:OnClose(callback)
    self.callbacks.onClose = callback
end

function WebSocketModule:OnError(callback)
    self.callbacks.onError = callback
end

function WebSocketModule:GetState()
    return self.readyState
end

function WebSocketModule:IsConnected()
    return self.readyState == OPEN
end

function WebSocketModule:ParseMessage(message)
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(message)
    end)
    
    if success then
        return data
    else
        return nil
    end
end

function WebSocketModule:CreateMessage(messageType, data, additionalData)
    local message = {
        type = messageType,
        data = data,
        timestamp = tick()
    }
    
    if additionalData then
        for key, value in pairs(additionalData) do
            message[key] = value
        end
    end
    
    return message
end

return WebSocketModule
