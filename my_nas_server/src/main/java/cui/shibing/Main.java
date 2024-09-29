package cui.shibing;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.sun.net.httpserver.HttpServer;
import cui.shibing.biz.common.CommonResult;
import cui.shibing.core.EventObj;
import cui.shibing.core.Model;
import cui.shibing.core.ModelFactory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public class Main {

    private static Logger logger = LoggerFactory.getLogger(Main.class);

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);

        server.createContext("/model", httpExchange -> {
            StringBuilder result = new StringBuilder();
            try {
                String path = httpExchange.getRequestURI().getPath();
                String[] urlPartition = path.split("/");

                if (urlPartition.length != 4) {
                    throw new IllegalArgumentException(String.format("%s url is error", path));
                }

                logger.info("接收到请求 path:{}, modeName:{} method:{}", path, urlPartition[2], urlPartition[3]);
                String modelName = urlPartition[2];
                String eventName = urlPartition[3];

                Model model = ModelFactory.getModel(modelName);
                if (model == null) {
                    throw new IllegalArgumentException(String.format("%s model not exists", modelName));
                }

                BufferedReader reader = new BufferedReader(new InputStreamReader(httpExchange.getRequestBody()));
                String b;
                do {
                    b = reader.readLine();
                    if (b != null) {
                        result.append(b);
                    }
                } while (b != null);

                JSONObject params = JSON.parseObject(result.toString());

                Object eventResult = model.sendEvent(new EventObj(eventName, params));
                Map<String, Object> resultObj = new HashMap<>();
                if (eventResult instanceof CommonResult) {
                    resultObj.putAll(((CommonResult) eventResult).populate());
                } else {
                    resultObj.put("result", eventResult);
                }
                resultObj.put("data", model.populate());

                result = new StringBuilder(JSON.toJSONString(resultObj));
            } catch (Exception e) {
                logger.error("catch exception",e);
                result = new StringBuilder(e.getMessage());
            }

            httpExchange.getResponseHeaders().add("Content-Type", "application/json");

            byte[] respBytes = result.toString().getBytes(StandardCharsets.UTF_8);
            httpExchange.sendResponseHeaders(200, respBytes.length);
            httpExchange.getResponseBody().write(respBytes);
            httpExchange.close();
        });

        server.start();
    }
}