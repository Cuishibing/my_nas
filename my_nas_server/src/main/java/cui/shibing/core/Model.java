package cui.shibing.core;

import java.util.Map;
import java.util.function.Function;

public interface Model {

    default String name() {
        return getClass().getSimpleName();
    }

    <T> void addEventListener(String handlerName, Function<EventObj, T> handler);

    <T> T sendEvent(EventObj event);

    default <T> T sendEvent(String eventName, Object... params) {
        EventObj e = new EventObj(eventName);
        if (params.length > 0) {
            for (int i = 0; i < params.length - 1; i += 2) {
                e.addAttribution(params[i].toString(), params[i + 1]);
            }
        }
        return sendEvent(e);
    }

    void init();

    Map<String, Object> populate();
}
