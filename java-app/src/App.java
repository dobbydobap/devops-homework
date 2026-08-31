import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class App {

    private static final int PORT = 8080;

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);
        server.createContext("/", App::handle);
        server.setExecutor(null);
        server.start();
        System.out.println("java app listening on " + PORT);
    }

    private static void handle(HttpExchange exchange) throws IOException {
        String body = "<h1>Hello World from Java</h1>";
        exchange.getResponseHeaders().set("Content-Type", "text/html");
        exchange.sendResponseHeaders(200, body.length());
        try (OutputStream out = exchange.getResponseBody()) {
            out.write(body.getBytes());
        }
    }
}
