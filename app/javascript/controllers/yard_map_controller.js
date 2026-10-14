import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"

// Medidas en metros: cada bahía es un lugar de 20 pies (contenedor ISO).
const SLOT = { length: 6.06, width: 2.44, height: 2.59 }
const GAP = { bay: 0.25, row: 0.5 }

// Distribución PROVISIONAL de los bloques (esquina de cada uno, en metros) hasta contar con el plano real.
// Las bahías crecen en +X y las filas (A, B, C...) en +Z.
const BLOCK_ORIGINS = {
  "1A": [0, 0], "1B": [0, 20], "1C": [0, 45],
  "1D": [150, 20], "2D": [185, 20], "3D": [220, 20]
}
const FALLBACK_ORIGIN_STEP = 40
const AREA_ORIGINS = { DESYCON: { origin: [0, -45], size: [70, 30] } }

const COLORS = { enabled: 0x6366f1, disabled: 0xf59e0b, selected: 0x10b981, ground: 0xe2e8f0, area: 0x34d399, background: 0xf1f5f9 }

export default class extends Controller {
  static targets = ["canvas", "info", "level", "block", "empty"]
  static values = { blocks: Array, areas: Array, disabled: Array, labels: Object }

  connect() {
    this.disabledCodes = new Set(this.disabledValue)
    this.slots = []
    this.selected = null
    this.setupScene()
    this.buildBlocks()
    this.buildAreas()
    this.paint()
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
    this.camera = new THREE.PerspectiveCamera(45, 1, 1, 3000)
    this.renderer = new THREE.WebGLRenderer({ antialias: true })
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.canvasTarget.appendChild(this.renderer.domElement)

    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x94a3b8, 1.6))
    const sun = new THREE.DirectionalLight(0xffffff, 1.2)
    sun.position.set(120, 200, 80)
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

  origin(code, index) {
    return BLOCK_ORIGINS[code] || [index * FALLBACK_ORIGIN_STEP, 90]
  }

  buildBlocks() {
    const placed = []
    this.blockViews = {}
    this.blocksValue.forEach((block, index) => {
      const [originX, originZ] = this.origin(block.code, index)
      const width = block.bays * (SLOT.length + GAP.bay)
      const depth = block.rows * (SLOT.width + GAP.row)

      const ground = new THREE.Mesh(
        new THREE.PlaneGeometry(width + 2, depth + 2),
        new THREE.MeshBasicMaterial({ color: COLORS.ground })
      )
      ground.rotation.x = -Math.PI / 2
      ground.position.set(originX + width / 2, -0.05, originZ + depth / 2)
      this.scene.add(ground)
      const label = this.addLabel(block.code, originX + width / 2, originZ - 4, 6)
      this.blockViews[block.code] = { ground, label, center: [originX + width / 2, originZ + depth / 2], extent: Math.max(width, depth) }

      for (let level = 1; level <= block.levels; level++) {
        for (let row = 0; row < block.rows; row++) {
          for (let bay = 1; bay <= block.bays; bay++) {
            const letter = String.fromCharCode(65 + row)
            placed.push({
              code: `${block.code}${bay}${letter}${level}`, block: block.code, bay, row: letter, level,
              position: new THREE.Vector3(
                originX + (bay - 1) * (SLOT.length + GAP.bay) + SLOT.length / 2,
                (level - 1) * SLOT.height + SLOT.height / 2,
                originZ + row * (SLOT.width + GAP.row) + SLOT.width / 2
              )
            })
          }
        }
      }
    })

    this.slots = placed
    this.mesh = new THREE.InstancedMesh(
      new THREE.BoxGeometry(SLOT.length * 0.96, SLOT.height * 0.96, SLOT.width * 0.96),
      new THREE.MeshStandardMaterial({ transparent: true, opacity: 0.55, roughness: 0.6 }),
      placed.length
    )
    this.scene.add(this.mesh)
    this.paint()
  }

  buildAreas() {
    this.areasValue.forEach((area) => {
      const config = AREA_ORIGINS[area.code]
      if (!config) return
      const [originX, originZ] = config.origin
      const [width, depth] = config.size
      const box = new THREE.Mesh(
        new THREE.BoxGeometry(width, 0.4, depth),
        new THREE.MeshStandardMaterial({ color: COLORS.area, transparent: true, opacity: area.enabled ? 0.7 : 0.25 })
      )
      box.position.set(originX + width / 2, 0.2, originZ + depth / 2)
      box.userData.area = area
      this.scene.add(box)
      this.areaMeshes = [ ...(this.areaMeshes || []), box ]
      const capacity = area.capacity ?? this.labelsValue.unknown
      box.userData.label = this.addLabel(`${area.name} · ${this.labelsValue.capacity}: ${capacity}`, originX + width / 2, originZ - 4, 6)
    })
  }

  addLabel(text, x, z, size) {
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
    sprite.position.set(x, 4, z)
    sprite.renderOrder = 10
    this.scene.add(sprite)
    return sprite
  }

  currentBlock() {
    return this.hasBlockTarget ? this.blockTarget.value : ""
  }

  // Colorea cada lugar y oculta los que no corresponden al nivel o bloque elegido.
  paint() {
    const level = this.hasLevelTarget ? this.levelTarget.value : ""
    const block = this.currentBlock()
    Object.entries(this.blockViews).forEach(([code, view]) => {
      view.ground.visible = view.label.visible = !block || code === block
    })
    if (this.areaMeshes) this.areaMeshes.forEach((mesh) => { mesh.visible = mesh.userData.label.visible = !block })
    const matrix = new THREE.Matrix4()
    const hidden = new THREE.Matrix4().makeScale(0, 0, 0)
    const color = new THREE.Color()

    this.slots.forEach((slot, index) => {
      const visible = (!level || slot.level === Number(level)) && (!block || slot.block === block)
      this.mesh.setMatrixAt(index, visible ? matrix.makeTranslation(slot.position.x, slot.position.y, slot.position.z) : hidden)
      const state = slot.code === this.selected ? "selected" : this.disabledCodes.has(slot.code) ? "disabled" : "enabled"
      this.mesh.setColorAt(index, color.setHex(COLORS[state]))
    })
    this.mesh.instanceMatrix.needsUpdate = true
    this.mesh.instanceColor.needsUpdate = true
    this.mesh.computeBoundingSphere()
    this.render()
  }

  filterLevel() {
    this.selected = null
    this.showInfo(null)
    this.paint()
  }

  filterBlock() {
    this.selected = null
    this.showInfo(null)
    this.paint()
    this.frameView()
  }

  pick(event) {
    const [startX, startY] = this.pointerStart || [event.clientX, event.clientY]
    if (Math.hypot(event.clientX - startX, event.clientY - startY) > 5) return

    const rect = this.renderer.domElement.getBoundingClientRect()
    const pointer = new THREE.Vector2(((event.clientX - rect.left) / rect.width) * 2 - 1, -((event.clientY - rect.top) / rect.height) * 2 + 1)
    this.raycaster.setFromCamera(pointer, this.camera)

    const hits = this.raycaster.intersectObject(this.mesh).filter((hit) => this.visibleInstance(hit.instanceId))
    const slot = hits.length ? this.slots[hits[0].instanceId] : null
    if (slot) {
      this.selected = slot.code
      this.showInfo(slot)
    } else {
      const area = this.areaMeshes && this.raycaster.intersectObjects(this.areaMeshes)[0]?.object.userData.area
      this.selected = null
      this.showInfo(null, area)
    }
    this.paint()
  }

  visibleInstance(index) {
    const level = this.hasLevelTarget ? this.levelTarget.value : ""
    const block = this.currentBlock()
    const slot = this.slots[index]
    return (!level || slot.level === Number(level)) && (!block || slot.block === block)
  }

  showInfo(slot, area) {
    const labels = this.labelsValue
    let html = `<p class="text-sm text-slate-500">${labels.hint}</p>`
    if (slot) {
      const state = this.disabledCodes.has(slot.code) ? labels.disabled : labels.enabled
      html = `<p class="font-mono text-xl font-bold text-slate-900">${slot.code}</p>
              <p class="text-sm text-slate-600">${labels.block} ${slot.block} · ${labels.bay} ${slot.bay} · ${labels.row} ${slot.row} · ${labels.level} ${slot.level}</p>
              <p class="mt-1 text-sm font-medium text-slate-800">${state}</p>`
    } else if (area) {
      html = `<p class="text-xl font-bold text-slate-900">${area.name}</p>
              <p class="text-sm text-slate-600">${labels.capacity}: ${area.capacity ?? labels.unknown}</p>`
    }
    this.infoTarget.innerHTML = html
  }

  frameView() {
    const view = this.blockViews?.[this.currentBlock()]
    if (view) {
      const [x, z] = view.center
      const aspect = this.camera.aspect || 1
      const distance = Math.max(view.extent * 1.2, 40) * Math.max(1, 1 / aspect)
      this.controls.target.set(x, 0, z)
      this.camera.position.set(x, distance * 1.1, z + distance * 0.6)
    } else {
      this.controls.target.set(110, 0, 20)
      this.camera.position.set(110, 170, 190)
    }
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

  // Render bajo demanda: solo se dibuja cuando algo cambia, para cuidar la batería en tablets.
  render() {
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => this.renderer.render(this.scene, this.camera))
  }
}
