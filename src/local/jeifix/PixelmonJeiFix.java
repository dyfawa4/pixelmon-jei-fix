package local.jeifix;

import mezz.jei.config.ServerInfo;
import mezz.jei.network.PacketHandler;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.ExtensionPoint;
import net.minecraftforge.fml.ModLoadingContext;
import net.minecraftforge.fml.network.FMLConnectionData;
import net.minecraftforge.fml.network.FMLNetworkConstants;
import net.minecraftforge.fml.network.NetworkHooks;
import org.apache.logging.log4j.LogManager;
import org.apache.commons.lang3.tuple.Pair;

/** Restore JEI detection after Pixelmon's bundled handshake replacement. */
@Mod("pixelmon_jei_fix")
public final class PixelmonJeiFix {
    public PixelmonJeiFix() {
        ModLoadingContext.get().registerExtensionPoint(ExtensionPoint.DISPLAYTEST,
            () -> Pair.of(() -> FMLNetworkConstants.IGNORESERVERONLY,
                (remoteVersion, isServer) -> true));
    }

    @Mod.EventBusSubscriber(modid = "pixelmon_jei_fix", value = Dist.CLIENT)
    public static final class ClientEvents {
        @SubscribeEvent(priority = EventPriority.LOWEST)
        public static void onLogin(ClientPlayerNetworkEvent.LoggedInEvent event) {
            if (event.getNetworkManager() == null) return;
            FMLConnectionData data = NetworkHooks.getConnectionData(event.getNetworkManager());
            // Never advertise JEI on a remote server that lacks its channel.
            // Preserve Forge's original decision if metadata is unavailable.
            if (data == null) {
                LogManager.getLogger("PixelmonJeiFix").warn(
                    "[PixelmonJeiFix] No negotiated channel metadata; kept original JEI detection");
                return;
            }
            boolean present = data.getChannels().containsKey(PacketHandler.CHANNEL_ID);
            ServerInfo.onConnectedToServer(present);
            LogManager.getLogger("PixelmonJeiFix").info(
                "[PixelmonJeiFix] Restored JEI server detection from negotiated channels: {}", present);
        }

        @SubscribeEvent(priority = EventPriority.LOWEST)
        public static void onLogout(ClientPlayerNetworkEvent.LoggedOutEvent event) {
            ServerInfo.onConnectedToServer(false);
        }
    }
}
