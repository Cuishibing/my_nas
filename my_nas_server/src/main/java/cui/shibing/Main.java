package cui.shibing;

import org.apache.catalina.Context;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.Wrapper;
import org.apache.catalina.startup.Tomcat;

import cui.shibing.core.http.CoreHttpServlet;
import jakarta.servlet.MultipartConfigElement;

public class Main {

    public static void main(String[] args) throws LifecycleException {
        // 创建 Tomcat 实例并设置端口
        Tomcat tomcat = new Tomcat();
        tomcat.setPort(8080);
        tomcat.getConnector();

        // 添加 Context
        Context context = tomcat.addContext("", null); // null 表示不使用 Web 应用目录

        // 添加 Servlet
        Wrapper wraper = Tomcat.addServlet(context, "coreHttpServlet", new CoreHttpServlet());
        wraper.setMultipartConfigElement(new MultipartConfigElement(null, 10 * 1024 * 1024, 10 * 1024 * 1024, 0));

        context.addServletMappingDecoded("/model/*", "coreHttpServlet");

        // 启动 Tomcat
        tomcat.start();
        tomcat.getServer().await();
    }
}