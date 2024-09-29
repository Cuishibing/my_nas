package cui.shibing.biz.testmodel;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;

public class DuplicateAttributionModel extends AnnotationSupportModel {
    @Attribution
    private String name;

    @Attribution("name")
    private String name1;
}
