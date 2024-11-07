package cui.shibing.core;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.querydsl.sql.SQLQueryFactory;
import cui.shibing.config.QueryDslConfig;
import cui.shibing.store.entity.QTModel;
import cui.shibing.store.entity.TModel;
import org.apache.commons.lang3.StringUtils;

import java.util.Map;

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
}
