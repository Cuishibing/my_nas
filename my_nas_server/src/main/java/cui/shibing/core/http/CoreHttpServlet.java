package cui.shibing.core.http;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.collections.CollectionUtils;
import org.apache.commons.lang3.StringUtils;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;

import cui.shibing.biz.common.CommonResult;
import cui.shibing.core.EventObj;
import cui.shibing.core.Model;
import cui.shibing.core.ModelFactory;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class CoreHttpServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        req.setCharacterEncoding("utf-8");
        resp.setCharacterEncoding("utf-8");
        String uri = req.getRequestURI();
        uri = uri.replace("/model/", "");
        String[] modelAndEvent = uri.split("/");

        String q = req.getQueryString();
        Map<String, String> queryParams = new HashMap<>();
        if (StringUtils.isNotBlank(q)) {
            String[] pairs = q.split("&");
            for (String pair : pairs) {
                int idx = pair.indexOf("=");
                if (idx > 0) {
                    String key = pair.substring(0, idx);
                    String value = pair.substring(idx + 1);
                    queryParams.put(key, value);
                }
            }
        }
        Model model;
        if (queryParams.containsKey("identifier")) {
            model = ModelFactory.getModel(modelAndEvent[0], queryParams.get("identifier"));
        } else {
            model = ModelFactory.getModel(modelAndEvent[0]);
        }

        Map<String, Object> params = new HashMap<>();

        String contetnType = req.getContentType();
        if (contetnType.equals("application/json")) {
            JSONObject body = JSON.parseObject(req.getReader());
            params.putAll(body);
            model.populate().putAll(params);
        } else if (contetnType.contains("multipart/form-data")) {
            var parts = req.getParts();
            if (CollectionUtils.isNotEmpty(parts)) {
                parts.forEach(part-> {
                    params.put(part.getName(), part);
                });
            }
        }

        var eventResult = model.sendEvent(new EventObj(modelAndEvent[1], params));
        Map<String, Object> resultObj = new HashMap<>();
        if (eventResult instanceof CommonResult) {
            resultObj.putAll(((CommonResult) eventResult).populate());
        } else {
            resultObj.put("result", eventResult);
        }
        resultObj.put("data", model.populate());

        var result = new StringBuilder(JSON.toJSONString(resultObj));
        resp.setContentType("application/json");
        resp.getWriter().write(result.toString());
    }

}
