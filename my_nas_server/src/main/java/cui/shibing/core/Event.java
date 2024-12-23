package cui.shibing.core;

import java.lang.annotation.*;

@Target({ElementType.METHOD})
@Documented
@Inherited
@Retention(RetentionPolicy.RUNTIME)
public @interface Event {
    String value() default "";
}
