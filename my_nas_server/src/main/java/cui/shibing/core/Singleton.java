package cui.shibing.core;

import java.lang.annotation.*;

@Target({ElementType.TYPE})
@Documented
@Inherited
@Retention(RetentionPolicy.RUNTIME)
public @interface Singleton {
}
