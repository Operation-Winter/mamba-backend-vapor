import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        "It works!"
    }

    app.get("hello") { req -> String in
        "Hello, world!"
    }
    
    app.webSocket(["planning", "host"]) { request, webSocket in
        print("Host", webSocket)
    }
    
    app.webSocket(["planning", "join"]) { request, webSocket in
        print("Join", webSocket)
    }
}
