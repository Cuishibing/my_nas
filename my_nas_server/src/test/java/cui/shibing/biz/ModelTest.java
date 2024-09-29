package cui.shibing.biz;

import cui.shibing.biz.testmodel.FakeModel;
import cui.shibing.biz.testmodel.SingletonModel;
import cui.shibing.core.*;
import org.junit.Assert;
import org.junit.Test;
import org.junit.function.ThrowingRunnable;

import java.util.Map;

public class ModelTest {

    @Test
    public void testPopulate() throws Exception {
        FakeModel fakeModel = ModelFactory.getModel("FakeModel");
        String result = fakeModel.sendEvent(new EventObj("test"));
        Assert.assertEquals("test_result", result);

        Map<String, Object> attributions = fakeModel.populate();
        Assert.assertEquals("{order_id=test_id, age=26, desc=i am test_id, age:26}", attributions.toString());
    }

    @Test
    public void testSingletonModel() {
        Model model1 = ModelFactory.getModel("SingletonModel");
        SingletonModel model2 = ModelFactory.getModel("SingletonModel");
        Assert.assertEquals(model1, model2);

        Model model3 = ModelFactory.getModel("FakeModel");
        Model model4 = ModelFactory.getModel("FakeModel");
        Assert.assertNotEquals(model3, model4);
    }

    @Test
    public void testDuplicateAttribution() {
        Assert.assertThrows(IllegalStateException.class, () -> ModelFactory.getModel("DuplicateAttributionModel"));
    }

    @Test
    public void testDuplicateEvent() {
        Assert.assertThrows(IllegalStateException.class, () -> ModelFactory.getModel("DuplicateEventModel"));
    }
}