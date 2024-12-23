package cui.shibing.config;

import com.mysql.cj.jdbc.MysqlDataSource;
import com.querydsl.sql.DefaultSQLExceptionTranslator;
import com.querydsl.sql.MySQLTemplates;
import com.querydsl.sql.SQLQueryFactory;

public class QueryDslConfig {

    public static com.querydsl.sql.Configuration configuration;

    public static SQLQueryFactory sqlQueryFactory;

    static {
        configuration = new com.querydsl.sql.Configuration(MySQLTemplates.builder().build());
        configuration.addListener(new QueryDslLoggingSqlListener());
        configuration.setExceptionTranslator(DefaultSQLExceptionTranslator.DEFAULT);
    }

    static {
        MysqlDataSource datasource = new MysqlDataSource();
        datasource.setUrl("jdbc:mysql://localhost:3306/mynas?serverTimezone=UTC");
        datasource.setUser("root");
        // datasource.setPassword("");
        sqlQueryFactory = new SQLQueryFactory(configuration, datasource);
    }

}
