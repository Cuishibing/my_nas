package cui.shibing.config;

import com.querydsl.sql.SQLBaseListener;
import com.querydsl.sql.SQLListenerContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class QueryDslLoggingSqlListener extends SQLBaseListener {

    private static final Logger logger = LoggerFactory.getLogger(QueryDslLoggingSqlListener.class);

    @Override
    public void executed(SQLListenerContext context) {
        String sql = context.getSQL() + "\t" + context.getSQLBindings().getNullFriendlyBindings();
        sql = sql.replace('\n', ' ');
        logger.info(sql);
    }
}
