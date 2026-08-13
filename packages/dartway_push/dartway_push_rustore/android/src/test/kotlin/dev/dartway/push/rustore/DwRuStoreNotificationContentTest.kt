package dev.dartway.push.rustore

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DwRuStoreNotificationContentTest {
    @Test
    fun `leaves the notification alone when the SDK already shows one`() {
        val content = resolveDwRuStoreNotificationContent(
            hasVisibleSdkNotification = true,
            messageData = mapOf("push_title" to "Title", "push_body" to "Body"),
        )

        assertNull(content)
    }

    @Test
    fun `draws a data-only message from the agreed keys`() {
        val content = resolveDwRuStoreNotificationContent(
            hasVisibleSdkNotification = false,
            messageData = mapOf(
                "push_title" to "  Title  ",
                "push_body" to "Body",
                "image_url" to "https://cdn.example.com/banner.png",
            ),
        )

        assertEquals("Title", content?.title)
        assertEquals("Body", content?.body)
        assertEquals("https://cdn.example.com/banner.png", content?.imageUrl)
    }

    @Test
    fun `stays silent for a data message that carries no text`() {
        val content = resolveDwRuStoreNotificationContent(
            hasVisibleSdkNotification = false,
            messageData = mapOf("type" to "new_post", "post_id" to "12"),
        )

        assertNull(content)
    }

    @Test
    fun `treats a blank image url as no image`() {
        val content = resolveDwRuStoreNotificationContent(
            hasVisibleSdkNotification = false,
            messageData = mapOf("push_title" to "Title", "image_url" to "   "),
        )

        assertNull(content?.imageUrl)
    }

    @Test
    fun `an empty sdk notification is not a visible one`() {
        assertEquals(false, hasVisibleSdkNotification(null, null))
        assertEquals(false, hasVisibleSdkNotification("", "  "))
        assertEquals(true, hasVisibleSdkNotification("Title", null))
    }
}
