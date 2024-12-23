package cui.shibing.core;

import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

public abstract class AbstractModel implements Model {

    private Map<String, Function<EventObj, ?>> eventListener;

    @Override
    public void init() {

    }

    @Override
    public <T> void addEventListener(String handlerName, Function<EventObj, T> handler) {
        if (eventListener == null) {
            eventListener = new HashMap<>();
        }
        eventListener.put(handlerName, handler);
    }

    @SuppressWarnings("unchecked")
    @Override
    public <T> T sendEvent(EventObj event) {
        if (eventListener == null) {
            return null;
        }
        Function<EventObj, ?> handler = eventListener.get(event.getName());
        if (handler == null) {
            return null;
        }
        return (T) handler.apply(event);
    }
}
