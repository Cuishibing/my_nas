package cui.shibing.core;

import java.io.FileInputStream;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.function.Function;

import jakarta.servlet.http.Part;

public class ModeEventListener<T> implements Function<EventObj, T> {

    private Method method;

    private Object target;

    public ModeEventListener(Method method, Object target) {
        this.method = method;
        this.target = target;
    }

    @SuppressWarnings("unchecked")
    @Override
    public T apply(EventObj event) {
        try {
            Class<?>[] paramTypes = method.getParameterTypes();
            if (paramTypes.length == 0) {
                return (T) method.invoke(target);
            }
            
            if (paramTypes.length == 1 && paramTypes[0] == EventObj.class) {
                return (T) method.invoke(target, event);
            }
            
            Object[] params = new Object[paramTypes.length];
            Map<String, Object> attributions = event.getAttributions();
            
            for (int i = 0; i < paramTypes.length; i++) {
                Param paramAnnotation = method.getParameters()[i].getAnnotation(Param.class);
                String paramName = paramAnnotation != null
                    ? paramAnnotation.value()
                    : method.getParameters()[i].getName();
                    
                Object value = attributions.get(paramName);
                if (value == null) {
                    throw new IllegalArgumentException("Required parameter '" + paramName + "' is missing or null");
                }
                
                if (paramTypes[i] == String.class) {
                    if (value instanceof Part) {
                        params[i] = new String(((Part)value).getInputStream().readAllBytes(), StandardCharsets.UTF_8);
                    } else {
                        params[i] = value.toString(); 
                    }
                } else if (paramTypes[i] == Integer.class || paramTypes[i] == int.class) {
                    params[i] = Integer.valueOf(new String(((Part)value).getInputStream().readAllBytes(), StandardCharsets.UTF_8));
                } else if (paramTypes[i] == Long.class || paramTypes[i] == long.class) {
                    params[i] = Long.valueOf(new String(((Part)value).getInputStream().readAllBytes(), StandardCharsets.UTF_8));
                } else if (paramTypes[i] == InputStream.class) {
                    if (value instanceof Part) {
                        params[i] = ((Part)value).getInputStream();
                    } else {
                        throw new IllegalArgumentException("Required parameter '" + paramName + "' type error, need Part");
                    }
                } else {
                    params[i] = value;
                }
            }
            
            return (T) method.invoke(target, params);
            
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
