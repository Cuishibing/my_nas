package cui.shibing.core;

import org.apache.commons.collections.MapUtils;
import org.apache.commons.lang3.BooleanUtils;
import org.apache.commons.lang3.StringUtils;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public abstract class AnnotationSupportModel extends AbstractModel {

    private static final Map<Class<?>, Map<String ,Field>> allAttributionFields = new HashMap<>();
    private static final Map<Class<?>, Map<String ,Method>> allAttributionGetMethods = new HashMap<>();
    private static final Map<Class<?>, Map<String ,Method>> allAttributionSetMethods = new HashMap<>();
    private static final Map<Class<?>, Map<String ,Method>> allEventMethods = new HashMap<>();

    private static final Map<Class<?>, Boolean> annotationIsParsed = new ConcurrentHashMap<>();

    public void parseAnnotations() {
        if (BooleanUtils.isTrue(annotationIsParsed.get(getClass()))) {
            return;
        }
        synchronized (AnnotationSupportModel.class) {
            if (BooleanUtils.isTrue(annotationIsParsed.get(getClass()))) {
                return;
            }

            Class<?> clazz = this.getClass();
            while (clazz != null && clazz != Object.class) {
                Field[] declaredFields = clazz.getDeclaredFields();
                Method[] declaredMethods = clazz.getDeclaredMethods();

                for (Field declaredField : declaredFields) {
                    if (!declaredField.isAnnotationPresent(Attribution.class)) {
                        continue;
                    }
                    String name = declaredField.getAnnotation(Attribution.class).value();
                    if (StringUtils.isBlank(name)) {
                        name = declaredField.getName();
                    }

                    String finalName = name;
                    allAttributionFields.compute(getClass(), (k, v)->{
                        if (v == null) {
                            v = new HashMap<>();
                        }
                        if (!v.containsKey(finalName)) {
                            v.put(finalName, declaredField);
                        } else {
                            throw new IllegalStateException(String.format("duplicate attribution %s in model %s", finalName, getClass()));
                        }
                        return v;
                    });
                }

                for (Method declaredMethod : declaredMethods) {
                    String name;
                    if (declaredMethod.isAnnotationPresent(Attribution.class)) {
                        name = declaredMethod.getAnnotation(Attribution.class).value();

                        Class<?> returnType = declaredMethod.getReturnType();
                        if (Void.class.equals(returnType)) {
                            // 认为是set方法
                            if (StringUtils.isBlank(name)) {
                                String methodName = declaredMethod.getName();
                                if ("set".equals(methodName)) {
                                    name = methodName;
                                } else {
                                    if (methodName.startsWith("set")) {
                                        name = methodName.replace("set", "");
                                        name = name.substring(0,1).toLowerCase() + name.substring(1);
                                    } else {
                                        name = methodName;
                                    }
                                }

                            }

                            String finalName = name;
                            allAttributionSetMethods.compute(getClass(), (k, v)->{
                                if (v == null) {
                                    v = new HashMap<>();
                                }
                                if (!v.containsKey(finalName)) {
                                    v.put(finalName, declaredMethod);
                                } else {
                                    throw new IllegalStateException(String.format("duplicate attribution %s in model %s", finalName, getClass()));
                                }
                                return v;
                            });
                        } else {
                            if (StringUtils.isBlank(name)) {
                                String methodName = declaredMethod.getName();
                                if ("get".equals(methodName)) {
                                    name = methodName;
                                } else {
                                    if (methodName.startsWith("get")) {
                                        name = methodName.replace("get", "");
                                        name = name.substring(0,1).toLowerCase() + name.substring(1);
                                    } else {
                                        name = methodName;
                                    }
                                }

                            }

                            String finalName = name;
                            allAttributionGetMethods.compute(getClass(), (k, v)->{
                                if (v == null) {
                                    v = new HashMap<>();
                                }
                                if (!v.containsKey(finalName)) {
                                    v.put(finalName, declaredMethod);
                                } else {
                                    throw new IllegalStateException(String.format("duplicate attribution %s in model %s", finalName, getClass()));
                                }
                                return v;
                            });
                        }
                    } else if (declaredMethod.isAnnotationPresent(Event.class)) {
                        name = declaredMethod.getAnnotation(Event.class).value();
                        if (StringUtils.isBlank(name)) {
                            name = declaredMethod.getName();
                        }

                        String finalName = name;
                        allEventMethods.compute(getClass(), (k, v)->{
                            if (v == null) {
                                v = new HashMap<>();
                            }
                            if (!v.containsKey(finalName)) {
                                v.put(finalName, declaredMethod);
                            } else {
                                throw new IllegalStateException(String.format("duplicate event %s in model %s", finalName, getClass()));
                            }
                            return v;
                        });
                    }
                }

                clazz = clazz.getSuperclass();
            }
            annotationIsParsed.put(getClass(), true);
        }
    }

    public void initAnnotationEvent() {
        parseAnnotations();
        Map<String, Method> events = allEventMethods.get(getClass());
        if (MapUtils.isEmpty(events)) {
            return;
        }
        for (Map.Entry<String, Method> nameAndMethod : allEventMethods.get(getClass()).entrySet()) {
            String name = nameAndMethod.getKey();
            Method method = nameAndMethod.getValue();

            this.addEventListener(name, new ModeEventListener<>(method, this));
        }
    }

    @Override
    public Map<String, Object> populate() {
        return new InnerAttributionMap(this);
    }

    public static class InnerAttributionMap implements Map<String, Object> {

        private AnnotationSupportModel model;
        private Map<String, Field> attrFieldMap;
        private Map<String, Method> attrGetMethodMap;

        public InnerAttributionMap(AnnotationSupportModel model) {
            this.model = model;
            this.model.parseAnnotations();
            this.attrFieldMap = allAttributionFields.get(model.getClass());
            this.attrGetMethodMap = allAttributionGetMethods.get(model.getClass());

            if (this.attrFieldMap == null) {
                this.attrFieldMap = new HashMap<>();
            }

            if (this.attrGetMethodMap == null) {
                this.attrGetMethodMap = new HashMap<>();
            }
        }

        @Override
        public int size() {
            return this.attrFieldMap.size() + this.attrGetMethodMap.size();
        }

        @Override
        public boolean isEmpty() {
            return this.attrFieldMap.isEmpty() && this.attrGetMethodMap.isEmpty();
        }

        @Override
        public boolean containsKey(Object key) {
            return this.attrFieldMap.containsKey(key) && this.attrGetMethodMap.containsKey(key);
        }

        @Override
        public boolean containsValue(Object value) {
            throw new UnsupportedOperationException("not support operation.");
        }

        @Override
        public Object get(Object key) {
            Field field = this.attrFieldMap.get(key);
            if (field != null) {
                field.setAccessible(true);
                try {
                    Object obj = field.get(this.model);
                    field.setAccessible(false);
                    return obj;
                } catch (IllegalAccessException e) {
                    throw new RuntimeException(e);
                }
            }

            Method method = this.attrGetMethodMap.get(key);
            if (method != null) {
                method.setAccessible(true);
                try {
                    Object obj = method.invoke(this.model);
                    method.setAccessible(false);
                    return obj;
                } catch (IllegalAccessException | InvocationTargetException e) {
                    throw new RuntimeException(e);
                }

            }
            return null;
        }

        @Override
        public Object put(String key, Object value) {
            Object before = get(key);
            Field field = this.attrFieldMap.get(key);
            if (field != null) {
                field.setAccessible(true);
                try {

                    if (field.getType() == Integer.class) {
                        Integer v = ((Number) value).intValue();
                        field.set(this.model, v);
                    } else if (field.getType() == Long.class) {
                        Long v = ((Number) value).longValue();
                        field.set(this.model, v);
                    } else {
                        field.set(this.model, value);
                    }
                    field.setAccessible(false);
                } catch (IllegalAccessException e) {
                    throw new RuntimeException(e);
                }
                return before;
            }

            Method method = this.attrGetMethodMap.get(key);
            if (method != null) {
                method.setAccessible(true);
                try {
                    method.invoke(this.model, value);
                    method.setAccessible(false);
                } catch (IllegalAccessException | InvocationTargetException e) {
                    throw new RuntimeException(e);
                }
                return before;
            }
            return null;
        }

        @Override
        public Object remove(Object key) {
            throw new UnsupportedOperationException("not support operation.");
        }

        @Override
        public void putAll(Map<? extends String, ?> m) {
            if (m == null) {
                return;
            }
            for (Entry<? extends String, ?> entry : m.entrySet()) {
                put(entry.getKey(), entry.getValue());
            }
        }

        @Override
        public void clear() {
            throw new UnsupportedOperationException("not support operation.");
        }

        @Override
        public Set<String> keySet() {
            Set<String> objects = new HashSet<>();
            objects.addAll(this.attrFieldMap.keySet());
            objects.addAll(this.attrGetMethodMap.keySet());
            return objects;
        }

        @Override
        public Collection<Object> values() {
            List<Object> values = new ArrayList<>();
            for (String key : this.keySet()) {
                Object value = this.get(key);
                values.add(value);
            }
            return values;
        }

        @Override
        public Set<Entry<String, Object>> entrySet() {
            Set<Entry<String, Object>> entrySet = new HashSet<>();
            for (String key : this.keySet()) {
                Object value = get(key);
                InnerEntry entry = new InnerEntry(this, key, value);
                entrySet.add(entry);
            }
            return entrySet;
        }

        public static class InnerEntry implements Entry<String, Object> {
            private InnerAttributionMap attributionMap;
            private String key;
            private Object value;

            public InnerEntry(InnerAttributionMap map, String key, Object value) {
                this.attributionMap = map;
                this.key = key;
                this.value = value;
            }
            @Override
            public String getKey() {
                return key;
            }

            @Override
            public Object getValue() {
                return value;
            }

            @Override
            public Object setValue(Object value) {
                return attributionMap.put(key, value);
            }
        }
    }
}
