package cui.shibing.store.entity;

import static com.querydsl.core.types.PathMetadataFactory.*;

import com.querydsl.core.types.dsl.*;

import com.querydsl.core.types.PathMetadata;
import javax.annotation.processing.Generated;
import com.querydsl.core.types.Path;

import com.querydsl.sql.ColumnMetadata;
import java.sql.Types;




/**
 * QTModel is a Querydsl query type for TModel
 */
@Generated("com.querydsl.sql.codegen.MetaDataSerializer")
public class QTModel extends com.querydsl.sql.RelationalPathBase<TModel> {

    private static final long serialVersionUID = 332904482;

    public static final QTModel tModel = new QTModel("t_model");

    public final StringPath attributions = createString("attributions");

    public final NumberPath<Long> ctime = createNumber("ctime", Long.class);

    public final NumberPath<Long> id = createNumber("id", Long.class);

    public final StringPath identifier = createString("identifier");

    public final StringPath modelName = createString("modelName");

    public final NumberPath<Long> utime = createNumber("utime", Long.class);

    public final NumberPath<Integer> valid = createNumber("valid", Integer.class);

    public final com.querydsl.sql.PrimaryKey<TModel> primary = createPrimaryKey(id);

    public QTModel(String variable) {
        super(TModel.class, forVariable(variable), "null", "t_model");
        addMetadata();
    }

    public QTModel(String variable, String schema, String table) {
        super(TModel.class, forVariable(variable), schema, table);
        addMetadata();
    }

    public QTModel(String variable, String schema) {
        super(TModel.class, forVariable(variable), schema, "t_model");
        addMetadata();
    }

    public QTModel(Path<? extends TModel> path) {
        super(path.getType(), path.getMetadata(), "null", "t_model");
        addMetadata();
    }

    public QTModel(PathMetadata metadata) {
        super(TModel.class, metadata, "null", "t_model");
        addMetadata();
    }

    public void addMetadata() {
        addMetadata(attributions, ColumnMetadata.named("attributions").withIndex(4).ofType(Types.VARCHAR).withSize(1024).notNull());
        addMetadata(ctime, ColumnMetadata.named("ctime").withIndex(5).ofType(Types.BIGINT).withSize(19).notNull());
        addMetadata(id, ColumnMetadata.named("id").withIndex(1).ofType(Types.BIGINT).withSize(19).notNull());
        addMetadata(identifier, ColumnMetadata.named("identifier").withIndex(2).ofType(Types.VARCHAR).withSize(128).notNull());
        addMetadata(modelName, ColumnMetadata.named("model_name").withIndex(3).ofType(Types.VARCHAR).withSize(128).notNull());
        addMetadata(utime, ColumnMetadata.named("utime").withIndex(6).ofType(Types.BIGINT).withSize(19).notNull());
        addMetadata(valid, ColumnMetadata.named("valid").withIndex(7).ofType(Types.INTEGER).withSize(10).notNull());
    }

}

