import Vapor

func routes(_ app: Application) throws {
    let planningSystem = PlanningSystem(eventLoop: app.eventLoopGroup.next())
    
    app.webSocket(["planning", "host"]) { request, webSocket in
        planningSystem.connect(webSocket, type: .host)
    }
    
    app.webSocket(["planning", "join"]) { request, webSocket in
        planningSystem.connect(webSocket, type: .join)
    }
}
