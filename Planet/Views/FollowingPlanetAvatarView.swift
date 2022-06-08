import Foundation
import SwiftUI

struct FollowingPlanetAvatarView: View {
    @ObservedObject var planet: FollowingPlanetModel

    var body: some View {
        VStack {
            if let image = planet.avatar {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80, alignment: .center)
                    .cornerRadius(40)
            } else {
                Text(planet.nameInitials)
                    .font(Font.custom("Arial Rounded MT Bold", size: 40))
                    .foregroundColor(Color.white)
                    .contentShape(Rectangle())
                    .frame(width: 80, height: 80, alignment: .center)
                    .background(LinearGradient(
                        gradient: ViewUtils.getPresetGradient(from: planet.id),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(40)
            }
        }
    }
}
