package cui.shibing.core;

import java.lang.reflect.Constructor;
import java.lang.reflect.Modifier;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.function.Supplier;

import org.apache.commons.lang3.StringUtils;
import org.reflections.Reflections;

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
            ((Storable)model).fetch(model, identifier);
        }

        if (model instanceof AnnotationSupportModel) {
            ((AnnotationSupportModel) model).initAnnotationEvent();
        }
        model.init();

        return (T) model;
    }
}
