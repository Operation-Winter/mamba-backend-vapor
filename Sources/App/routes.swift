import Vapor
import NIO

func routes(_ app: Application) throws {
    let planningSystem = PlanningSystem(eventLoop: app.eventLoopGroup.next())
    
    app.webSocket(["planning", "host"]) { request, webSocket in
        webSocket.pingInterval = .seconds(20)
        planningSystem.connect(webSocket, type: .host)
    }
    
    app.webSocket(["planning", "join"]) { request, webSocket in
        webSocket.pingInterval = .seconds(20)
        planningSystem.connect(webSocket, type: .join)
    }
}
