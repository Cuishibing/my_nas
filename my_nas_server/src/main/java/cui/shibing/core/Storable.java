package cui.shibing.core;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.querydsl.core.BooleanBuilder;
import com.querydsl.core.types.Predicate;
import com.querydsl.core.types.dsl.Expressions;
import com.querydsl.sql.SQLQueryFactory;
import cui.shibing.config.QueryDslConfig;
import cui.shibing.store.entity.QTModel;
import cui.shibing.store.entity.TModel;
import org.apache.commons.lang3.StringUtils;

import java.util.*;

public interface Storable {
    String getIdentifier();

    default boolean exist() {
        if (StringUtils.isBlank(getIdentifier())) {
            return false;
        }
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;

        TModel modelData = factory.selectFrom(table).where(table.identifier.eq(getIdentifier()).and(table.modelName.eq(getClass().getSimpleName())).and(table.valid.eq(1))).fetchOne();
        if (modelData == null || StringUtils.isBlank(modelData.getAttributions())) {
            return false;
        }
        return true;
    }

    default boolean save(Model model) {
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;

        TModel modelData = factory.selectFrom(table).where(table.identifier.eq(getIdentifier()).and(table.modelName.eq(model.name())).and(table.valid.eq(1))).fetchOne();
        if (modelData == null) {
            modelData = new TModel();
            modelData.setModelName(model.name());
            modelData.setIdentifier(getIdentifier());
            modelData.setAttributions(JSON.toJSONString(model.populate()));
            modelData.setCtime(System.currentTimeMillis() / 1000);
            modelData.setUtime(System.currentTimeMillis() / 1000);
            modelData.setValid(1);

            return factory.insert(table).populate(modelData).executeWithKey(table.id) > 0;
        } else {
            modelData.setAttributions(JSON.toJSONString(model.populate()));
            modelData.setUtime(System.currentTimeMillis() / 1000);

            return factory.update(table).populate(modelData).where(table.id.eq(modelData.getId()).and(table.identifier.eq(getIdentifier())).and(table.modelName.eq(model.name())).and(table.valid.eq(1))).execute() > 0;
        }
    }

    default void fetch(Model model, String identifier) {
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;

        TModel modelData = factory.selectFrom(table).where(table.identifier.eq(identifier).and(table.modelName.eq(getClass().getSimpleName())).and(table.valid.eq(1))).fetchOne();
        Map<String, Object> attrMap = model.populate();
        if (modelData == null || StringUtils.isBlank(modelData.getAttributions())) {
            return;
        }

        JSONObject jsonObject = JSON.parseObject(modelData.getAttributions());
        attrMap.putAll(jsonObject);
    }

    // 条件构建器类
    class Condition {
        private final Map<String, Object> andConditions = new HashMap<>();
        private final List<Map<String, Object>> orConditions = new ArrayList<>();

        public Condition and(String key, Object value) {
            andConditions.put(key, value);
            return this;
        }

        public Condition or(Map<String, Object> conditions) {
            orConditions.add(conditions);
            return this;
        }
    }

    // 根据条件查询单个结果
    default TModel findOne(Condition condition) {
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;
        
        BooleanBuilder whereClause = new BooleanBuilder();
        whereClause.and(table.modelName.eq(getClass().getSimpleName()));
        whereClause.and(table.valid.eq(1));
        
        // 处理AND条件
        for (Map.Entry<String, Object> entry : condition.andConditions.entrySet()) {
            whereClause.and(buildJsonCondition(table, entry.getKey(), entry.getValue()));
        }
        
        // 处理OR条件
        BooleanBuilder orClause = new BooleanBuilder();
        for (Map<String, Object> orCondition : condition.orConditions) {
            BooleanBuilder subClause = new BooleanBuilder();
            for (Map.Entry<String, Object> entry : orCondition.entrySet()) {
                subClause.and(buildJsonCondition(table, entry.getKey(), entry.getValue()));
            }
            orClause.or(subClause);
        }
        
        if (orClause.hasValue()) {
            whereClause.and(orClause);
        }

        return factory.selectFrom(table)
                     .where(whereClause)
                     .fetchFirst();
    }

    // 根据条件查询多个结果
    default List<TModel> findAll(Condition condition) {
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;
        
        BooleanBuilder whereClause = new BooleanBuilder();
        whereClause.and(table.modelName.eq(getClass().getSimpleName()));
        whereClause.and(table.valid.eq(1));
        
        // 处理AND条件
        for (Map.Entry<String, Object> entry : condition.andConditions.entrySet()) {
            whereClause.and(buildJsonCondition(table, entry.getKey(), entry.getValue()));
        }
        
        // 处理OR条件
        BooleanBuilder orClause = new BooleanBuilder();
        for (Map<String, Object> orCondition : condition.orConditions) {
            BooleanBuilder subClause = new BooleanBuilder();
            for (Map.Entry<String, Object> entry : orCondition.entrySet()) {
                subClause.and(buildJsonCondition(table, entry.getKey(), entry.getValue()));
            }
            orClause.or(subClause);
        }
        
        if (orClause.hasValue()) {
            whereClause.and(orClause);
        }

        return factory.selectFrom(table)
                     .where(whereClause)
                     .fetch();
    }

    // 构建JSON查询条件
    private static Predicate buildJsonCondition(QTModel table, String key, Object value) {
        String jsonPath = String.format("$.%s", key);
        if (value instanceof String) {
            // 对于字符串值，使用JSON_UNQUOTE去除引号后比较
            return Expressions.booleanTemplate(
                "JSON_UNQUOTE(JSON_EXTRACT({0}, {1})) = {2}",
                table.attributions,
                jsonPath,
                value.toString()
            );
        } else if (value instanceof Number) {
            // 对于数字类型，直接使用JSON_EXTRACT比较
            return Expressions.booleanTemplate(
                "JSON_EXTRACT({0}, {1}) = {2}",
                table.attributions,
                jsonPath,
                value.toString()
            );
        } else if (value instanceof Boolean) {
            // 对于布尔类型
            return Expressions.booleanTemplate(
                "JSON_EXTRACT({0}, {1}) = {2}",
                table.attributions,
                jsonPath,
                value.toString()
            );
        } else if (value == null) {
            // 处理null值
            return Expressions.booleanTemplate(
                "JSON_EXTRACT({0}, {1}) IS NULL",
                table.attributions,
                jsonPath
            );
        }
        return null;
    }

    // 添加一个新的方法支持模糊查询
    private static Predicate buildJsonLikeCondition(QTModel table, String key, String value) {
        String jsonPath = String.format("$.%s", key);
        return Expressions.booleanTemplate(
            "JSON_UNQUOTE(JSON_EXTRACT({0}, {1})) LIKE {2}",
            table.attributions,
            jsonPath,
            "%" + value + "%"
        );
    }
}
