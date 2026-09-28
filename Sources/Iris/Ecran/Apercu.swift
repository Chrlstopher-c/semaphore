// L'aperçu de la caméra, rangé exactement comme la webcam des PC le reçoit.
#if canImport(UIKit)
import AVFoundation
import SwiftUI

struct Apercu: UIViewRepresentable {
    let couche: AVCaptureVideoPreviewLayer
    let remplir: Bool

    func makeUIView(context: Context) -> VueApercu {
        let vue = VueApercu()
        vue.backgroundColor = .black
        vue.layer.addSublayer(couche)
        return vue
    }

    func updateUIView(_ vue: VueApercu, context: Context) {
        couche.videoGravity = remplir ? .resizeAspectFill : .resizeAspect
        vue.setNeedsLayout()
    }
}

final class VueApercu: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayers?.forEach { $0.frame = bounds }
        CATransaction.commit()
    }
}
#endif
