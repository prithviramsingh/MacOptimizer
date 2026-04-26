import CoreGraphics

enum DS {
    enum Space {
        static let xs: CGFloat  =  4
        static let sm: CGFloat  =  8
        static let md: CGFloat  = 14
        static let lg: CGFloat  = 20
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card:    CGFloat = 14
        static let button:  CGFloat =  8
        static let navItem: CGFloat =  9
        static let icon:    CGFloat = 10
        static let chip:    CGFloat = 999
    }

    enum Size {
        static let sidebarWidth: CGFloat  = 232
        static let toolbarHeight: CGFloat =  38
        static let detailWidth: CGFloat   = 320
    }
}
