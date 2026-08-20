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
            guard await clients.reserve(uuid) else {
                sendInvalidCommand(error: .invalidUuid, type: .spectator, webSocket: webSocket)
                return
            }
            guard let session = await sessions.find(id: message.sessionCode),
                  session.password == message.password
            else {
                await clients.release(uuid)
                sendInvalidSessionCommandSpectator(error: .doesntExist, webSocket: webSocket)
                return
            }
            
            let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: session.id, type: .spectator, connected: true)
            await clients.add(client)
            
            let spectator = PlanningSpectator(spectatorId: client.id)
            
            await session.add(spectator: spectator)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Leave session command
    func leaveSessionSpectator(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .spectator, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .spectator, webSocket: webSocket)
                return
            }
            await session.remove(spectatorId: uuid)
            await clients.close(uuid)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Reconnect command
    func reconnectSpectate(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await reconnectingClient(uuid: uuid, type: .spectator, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .spectator, webSocket: webSocket)
                return
            }
            
            await session.sendState(to: uuid)
        }
    }
}
