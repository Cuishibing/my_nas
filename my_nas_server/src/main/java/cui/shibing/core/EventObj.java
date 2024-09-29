package cui.shibing.core;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public class EventObj {

    private String name;
    private Map<String, Object> attributions;

    public EventObj(String name) {
        this.name = name;
    }

    public EventObj(String name, Map<String,Object> attributions) {
        this.name = name;
        this.attributions = attributions;
    }

    public String getName() {
        return name;
    }

    public void addAttribution(String key, Object value) {
        if (attributions == null) {
            attributions = new HashMap<>();
        }
        attributions.put(key, value);
    }

    @SuppressWarnings("unchecked")
    public <T> T getAttribution(String key) {
        if (attributions == null) {
            return null;
        }
        return (T)attributions.get(key);
    }

    public Long getLongAttribution(String key) {
        Object att = getAttribution(key);
        if (att == null) {
            return null;
        }
        return Long.valueOf(att.toString());
    }

    public Integer getIntegerAttribution(String key) {
        Object att = getAttribution(key);
        if (att == null) {
            return null;
        }
        return Integer.valueOf(att.toString());
    }

    public String getStringAttribution(String key) {
        Object att = getAttribution(key);
        if (att == null) {
            return null;
        }
        return att.toString();
    }

    public Map<String , Object> getAttributions() {
        if (attributions == null) {
            return Collections.emptyMap();
        }
        return attributions;
    }
}
