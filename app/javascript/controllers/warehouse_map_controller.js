import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"

// Proporciones aproximadas en metros: cada ubicación de piso cabe unos 3 contenedores.
const SLOT = { width: 7, depth: 6 }
const GAP = 1
const COLUMN_GAP = 4
const BAY_GAP = 14
const ROWS_PER_COLUMN = 8
const FREE_SPACE = 6
// Pasillo en todas las naves y columnas tras la segunda fila: entre 2 y 3 (izquierda) y entre 15 y 14 (derecha).
const AISLE_AFTER_ROWS = 2
const COLORS = { empty: 0x7dd3fc, stored: 0xf59e0b, disabled: 0x94a3b8, selected: 0x10b981, ground: 0xe2e8f0, background: 0xf1f5f9 }

export default class extends Controller {
  static targets = ["canvas", "info"]
  static values = { bays: Array, labels: Object }

  connect() {
    this.selected = null
    this.meshes = []
    this.setupScene()
    this.buildBays()
    this.frameView()
    this.resizeObserver = new ResizeObserver(() => this.resize())
    this.resizeObserver.observe(this.canvasTarget)
    this.resize()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    cancelAnimationFrame(this.frame)
    this.controls?.dispose()
    this.scene?.traverse((object) => {
      object.geometry?.dispose()
      const materials = [].concat(object.material || [])
      materials.forEach((material) => { material.map?.dispose(); material.dispose() })
    })
    this.renderer?.dispose()
    this.renderer?.domElement.remove()
  }

  setupScene() {
    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(COLORS.background)
    this.camera = new THREE.PerspectiveCamera(45, 1, 1, 1500)
    this.renderer = new THREE.WebGLRenderer({ antialias: true })
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.canvasTarget.appendChild(this.renderer.domElement)

    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x94a3b8, 1.6))
    const sun = new THREE.DirectionalLight(0xffffff, 1.1)
    sun.position.set(60, 120, 40)
    this.scene.add(sun)

    this.controls = new OrbitControls(this.camera, this.renderer.domElement)
    this.controls.enableDamping = false
    this.controls.maxPolarAngle = Math.PI / 2 - 0.05
    this.controls.addEventListener("change", () => this.render())

    this.raycaster = new THREE.Raycaster()
    const element = this.renderer.domElement
    element.addEventListener("pointerdown", (event) => { this.pointerStart = [event.clientX, event.clientY] })
    element.addEventListener("pointerup", (event) => this.pick(event))
  }

  // Cada nave tiene dos columnas de 8 ubicaciones enfrentadas; la nave 1 deja un espacio libre tras la ubicación indicada, solo en la primera columna.
  buildBays() {
    const columnWidth = SLOT.width + GAP
    const bayWidth = columnWidth * 2 + COLUMN_GAP
    this.bounds = { minX: 0, maxX: 0, maxZ: 0 }

    this.baysValue.forEach((bay, index) => {
      const originX = index * (bayWidth + BAY_GAP)
      const ground = new THREE.Mesh(new THREE.PlaneGeometry(bayWidth, 1), new THREE.MeshBasicMaterial({ color: COLORS.ground }))
      ground.rotation.x = -Math.PI / 2
      this.scene.add(ground)
      this.addLabel(bay.label, originX + bayWidth / 2, -5, 5)
      let depth = 0

      bay.slots.forEach((slot) => {
        const column = slot.number <= ROWS_PER_COLUMN ? 0 : 1
        // La columna 9-16 va en orden descendente: el 16 frente al 1 y el 9 frente al 8.
        const row = column === 0 ? slot.number - 1 : 2 * ROWS_PER_COLUMN - slot.number
        // El +GAP alinea 5, 6 y 7 de la nave 1 con 11, 10 y 9 de la segunda columna.
        const bayGap = bay.free_space_after && column === 0 && slot.number > bay.free_space_after ? FREE_SPACE + GAP : 0
        const afterFree = bayGap + (row >= AISLE_AFTER_ROWS ? FREE_SPACE : 0)
        const height = slot.enabled ? 0.6 + Math.min(slot.items, 6) * 0.5 : 0.3
        const mesh = new THREE.Mesh(
          new THREE.BoxGeometry(SLOT.width, height, SLOT.depth),
          new THREE.MeshStandardMaterial({ color: this.colorFor(slot), roughness: 0.6 })
        )
        mesh.position.set(
          originX + column * (columnWidth + COLUMN_GAP) + SLOT.width / 2,
          height / 2,
          row * (SLOT.depth + GAP) + SLOT.depth / 2 + afterFree
        )
        depth = Math.max(depth, mesh.position.z + SLOT.depth / 2)
        mesh.userData = { slot }
        this.scene.add(mesh)
        this.meshes.push(mesh)
        this.addLabel(String(slot.number), mesh.position.x, mesh.position.z, 3, height + 1.5)
      })

      // El piso llega hasta el borde de la última ubicación de la nave.
      ground.scale.y = depth + 2
      ground.position.set(originX + bayWidth / 2, -0.05, depth / 2)
      this.bounds.maxX = originX + bayWidth
      this.bounds.maxZ = Math.max(this.bounds.maxZ, depth)
    })
  }

  colorFor(slot) {
    if (this.selected === slot.code) return COLORS.selected
    if (!slot.enabled) return COLORS.disabled
    if (slot.items > 0 && /^#[0-9a-f]{6}$/i.test(slot.color || "")) return parseInt(slot.color.slice(1), 16)
    return slot.items > 0 ? COLORS.stored : COLORS.empty
  }

  addLabel(text, x, z, size, y = 3) {
    const canvas = document.createElement("canvas")
    const context = canvas.getContext("2d")
    context.font = "bold 56px sans-serif"
    canvas.width = Math.ceil(context.measureText(text).width) + 32
    canvas.height = 88
    context.font = "bold 56px sans-serif"
    context.fillStyle = "#1e293b"
    context.textBaseline = "middle"
    context.fillText(text, 16, 44)
    const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(canvas), depthTest: false }))
    sprite.scale.set(size * (canvas.width / canvas.height), size, 1)
    sprite.position.set(x, y, z)
    sprite.renderOrder = 10
    this.scene.add(sprite)
  }

  pick(event) {
    const [startX, startY] = this.pointerStart || [event.clientX, event.clientY]
    if (Math.hypot(event.clientX - startX, event.clientY - startY) > 5) return

    const rect = this.renderer.domElement.getBoundingClientRect()
    const pointer = new THREE.Vector2(((event.clientX - rect.left) / rect.width) * 2 - 1, -((event.clientY - rect.top) / rect.height) * 2 + 1)
    this.raycaster.setFromCamera(pointer, this.camera)

    const hit = this.raycaster.intersectObjects(this.meshes)[0]
    this.selected = hit ? hit.object.userData.slot.code : null
    this.meshes.forEach((mesh) => mesh.material.color.setHex(this.colorFor(mesh.userData.slot)))
    this.showInfo(hit ? hit.object.userData.slot : null)
    this.render()
  }

  showInfo(slot) {
    const labels = this.labelsValue
    let html = `<p class="text-sm text-slate-500">${labels.hint}</p>`
    if (slot) {
      const sections = Object.entries(slot.sections).map(([section, count]) => `${section}: ${count}`).join(" · ")
      html = `<p class="font-mono text-xl font-bold text-slate-900">${slot.code}</p>
              <p class="text-sm text-slate-600">${sections}</p>
              ${slot.clients.length ? `<p class="text-sm text-slate-600">${slot.clients.join(" · ")}</p>` : ""}
              <a href="${slot.url}" class="mt-2 inline-flex min-h-12 items-center rounded-full bg-sky-800 px-5 font-medium text-white transition-all duration-200 ease-out hover:bg-sky-900 active:scale-95">${labels.open}</a>`
    }
    this.infoTarget.innerHTML = html
  }

  frameView() {
    const x = this.bounds.maxX / 2
    const z = this.bounds.maxZ / 2
    const distance = Math.max(this.bounds.maxX, this.bounds.maxZ) * 1.1 * Math.max(1, 1 / (this.camera.aspect || 1))
    this.controls.target.set(x, 0, z)
    this.camera.position.set(x, distance, z + distance * 0.7)
    this.controls.update()
  }

  resetView() {
    this.frameView()
    this.render()
  }

  resize() {
    const { clientWidth, clientHeight } = this.canvasTarget
    if (!clientWidth || !clientHeight) return
    this.renderer.setSize(clientWidth, clientHeight)
    this.camera.aspect = clientWidth / clientHeight
    this.camera.updateProjectionMatrix()
    this.render()
  }

  // Render bajo demanda para cuidar la batería en tablets.
  render() {
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => this.renderer.render(this.scene, this.camera))
  }
}
