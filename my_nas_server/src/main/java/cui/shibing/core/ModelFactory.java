package cui.shibing.core;

import com.alibaba.fastjson2.JSON;
import com.querydsl.core.BooleanBuilder;
import com.querydsl.core.types.Predicate;
import com.querydsl.core.types.dsl.Expressions;
import com.querydsl.sql.SQLQueryFactory;
import cui.shibing.config.QueryDslConfig;
import cui.shibing.store.entity.QTModel;
import cui.shibing.store.entity.TModel;
import org.apache.commons.lang3.StringUtils;
import org.reflections.Reflections;

import java.lang.reflect.Constructor;
import java.lang.reflect.Modifier;
import java.util.*;
import java.util.function.Supplier;

public class ModelFactory {

    private static final Map<String, Supplier<Model>> modelMap = new HashMap<>();

    public static void registerModel(String name, Supplier<Model> modelSupplier) {
        modelMap.put(name, modelSupplier);
    }

    static {
        Reflections reflections = new Reflections("cui.shibing.biz"); // 替换为你的包名

        // 获取实现了某个接口的类
        Set<Class<? extends Model>> subTypesOfModel = reflections.getSubTypesOf(Model.class);// 替换为你的接口

        for (Class<? extends Model> clazz : subTypesOfModel) {
            int modifiers = clazz.getModifiers();
            if (Modifier.isAbstract(modifiers) || Modifier.isInterface(modifiers) || Modifier.isPrivate(modifiers)) {
                continue;
            }
            String name = clazz.getSimpleName();

            Singleton singleton = clazz.getAnnotation(Singleton.class);
            if (singleton != null) {
                try {
                    Constructor<? extends Model> constructor = clazz.getConstructor();
                    Model model = constructor.newInstance();
                    registerModel(name, () -> model);
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            } else {
                registerModel(name, () -> {
                    try {
                        Constructor<? extends Model> constructor = clazz.getConstructor();
                        return constructor.newInstance();
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                });
            }
        }
    }

    @SuppressWarnings("unchecked")
    public static <T extends Model> T getModel(String modelName) {
        Supplier<Model> modelSupplier = modelMap.get(modelName);
        if (modelSupplier == null) {
            return null;
        }
        Model model = modelSupplier.get();

        if (model instanceof AnnotationSupportModel) {
            ((AnnotationSupportModel) model).initAnnotationEvent();
        }
        model.init();

        return (T) model;
    }

    @SuppressWarnings("unchecked")
    public static <T extends Model> T getModel(String modelName, String identifier) {
        Supplier<Model> modelSupplier = modelMap.get(modelName);
        if (modelSupplier == null) {
            throw new IllegalStateException(String.format("not register %s model", modelName));
        }
        Model model = modelSupplier.get();

        if (StringUtils.isNotBlank(identifier)) {
            if (!(model instanceof Storable)) {
                throw new UnsupportedOperationException("not storable model");
            }
            ((Storable) model).fetch(model, identifier);
        }

        if (model instanceof AnnotationSupportModel) {
            ((AnnotationSupportModel) model).initAnnotationEvent();
        }
        model.init();

        return (T) model;
    }

    // 条件构建器类
    public static class Condition {
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
    public static <T extends Model> T getModel(String modelName, Condition condition) {
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;

        BooleanBuilder whereClause = new BooleanBuilder();
        whereClause.and(table.modelName.eq(modelName));
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

        TModel modelData = factory.selectFrom(table)
                .where(whereClause)
                .fetchFirst();

        if (modelData == null) {
            return null;
        }

        T model = getModel(modelName);
        if (StringUtils.isNotBlank(modelData.getAttributions())) {
            model.populate().putAll(JSON.parseObject(modelData.getAttributions()));
        }
        return model;
    }

    // 根据条件查询多个结果
    public static <T extends Model> List<T> getModels(String modelName, Condition condition) {
        SQLQueryFactory factory = QueryDslConfig.sqlQueryFactory;
        QTModel table = QTModel.tModel;

        BooleanBuilder whereClause = new BooleanBuilder();
        whereClause.and(table.modelName.eq(modelName));
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

        List<TModel> modelDataList = factory.selectFrom(table)
                .where(whereClause)
                .fetch();

        List<T> results = new ArrayList<>();
        for (TModel modelData : modelDataList) {
            T model = getModel(modelName);
            if (StringUtils.isNotBlank(modelData.getAttributions())) {
                model.populate().putAll(JSON.parseObject(modelData.getAttributions()));
            }
            if (model != null) {
                results.add(model);
            }
        }

        return results;
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

    // 添加模糊查询支持
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
