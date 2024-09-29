package cui.shibing.core;

import java.lang.annotation.*;

@Target({ElementType.FIELD, ElementType.METHOD})
@Documented
@Inherited
@Retention(RetentionPolicy.RUNTIME)
public @interface Attribution {
    String value() default "";
}
