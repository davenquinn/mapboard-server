export default function metadataRoutes(app) {
  app.get("/capabilities", function (req, res) {
    return [
      "basic-editing", // Tools defined in version 1 of the app
      "reshape",
      "topology"
    ]
  })
}
