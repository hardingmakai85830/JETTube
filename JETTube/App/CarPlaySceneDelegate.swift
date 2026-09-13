import UIKit
import CarPlay
import MediaPlayer

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    
    // MARK: - CPTemplateApplicationSceneDelegate
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        // Show Now Playing template — displays current audio with controls
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        interfaceController.setRootTemplate(nowPlayingTemplate, animated: true, completion: nil)
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
}
