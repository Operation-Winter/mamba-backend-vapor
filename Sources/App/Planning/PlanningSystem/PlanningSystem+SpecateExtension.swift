import Foundation
import MambaNetworking
import Vapor

// MARK: - Spectate related command methods
extension PlanningSystem {
    func execute(command: PlanningCommands.SpectatorServerReceive, webSocket: WebSocket) {
        switch command {
        case .joinSession(let uuid, let message):
            joinSpectateSession(message: message, webSocket: webSocket, uuid: uuid)
        case .leaveSession(let uuid):
            leaveSessionSpectator(webSocket: webSocket, uuid: uuid)
        case .reconnect(let uuid):
            reconnectSpectate(webSocket: webSocket, uuid: uuid)
        }
    }
    
    // MARK: Join spectate session command
    func joinSpectateSession(message: PlanningSpectateSessionMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let session = await sessions.find(id: message.sessionCode),
                  session.password == message.password
            else {
                sendInvalidSessionCommandSpectator(error: .doesntExist, webSocket: webSocket)
                return
            }
            
            let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: session.id.value, type: .spectator, connected: true)
            clients.add(client)
            
            let spectator = PlanningSpectator(spectatorId: client.id)
            
            await session.add(spectator: spectator)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Leave session command
    func leaveSessionSpectator(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .spectator, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.remove(spectatorId: uuid)
            clients.close(uuid)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Reconnect command
    func reconnectSpectate(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .spectator, webSocket: webSocket)
                return
            }
            
            client.socket = webSocket
            client.connected = true
            await session.sendState(to: uuid)
        }
    }
}
