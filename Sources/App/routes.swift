import Vapor
import NIO

func routes(_ app: Application) throws {
    let planningSystem = PlanningSystem(eventLoop: app.eventLoopGroup.next())
    
    app.webSocket(["api", "planning", "host"]) { request, webSocket in
        planningSystem.connect(webSocket, type: .host)
    }
    
    app.webSocket(["api", "planning", "join"]) { request, webSocket in
        planningSystem.connect(webSocket, type: .join)
    }
}
