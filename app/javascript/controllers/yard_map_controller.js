import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls.js"

// Medidas en metros: cada bahía es un lugar de 20 pies (contenedor ISO).
const SLOT = { length: 6.06, width: 2.44, height: 2.59 }
const GAP = { bay: 0.25, row: 0.5 }

// Distribución de los bloques según el diagrama del patio (esquina de cada uno, en metros).
// Por omisión las bahías crecen en +X y las filas (A, B, C...) en +Z; con rotated, bahías en +Z y filas en +X.
// reverseRows dibuja las filas en orden inverso (la A donde estaría la última). Solo afecta al mapa.
// Separaciones: 1CFS-2CFS = 2CFS-3CFS = 15 m; 1A-1CFS = 3CFS-1C = 40 m.
const BLOCK_LAYOUT = {
  "1A": { origin: [0, 0] },
  "1CFS": { origin: [108, 45.9], rotated: true },
  "2CFS": { origin: [108, 86.1], rotated: true },
  "3CFS": { origin: [108, 126.3], rotated: true },
  "1C": { origin: [82, 191.5], reverseRows: true },
  "1B": { origin: [244, 60.9], rotated: true, reverseRows: true }
}
// Los bloques CFS forman el área de DesyCon.
const DESYCON_BLOCKS = [ "1CFS", "2CFS", "3CFS" ]
const FALLBACK_ORIGIN_STEP = 40

const UPRIGHT = new THREE.Quaternion()
const ROTATED = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.PI / 2)
const COLORS = { enabled: 0x6366f1, disabled: 0xf59e0b, occupied: 0xdc2626, containerRib: 0xfca5a5, corner: 0xf59e0b, selected: 0x10b981, ground: 0xe2e8f0, area: 0xa7f3d0, unassigned: 0xcbd5e1, background: 0xf1f5f9 }

export default class extends Controller {
  static targets = ["canvas", "info", "level", "block", "empty", "areasToggle", "legend"]
  static values = { blocks: Array, disabled: Array, labels: Object, occupied: Array, sections: Array }

  connect() {
    this.disabledCodes = new Set(this.disabledValue)
    this.occupiedByCode = new Map()
    this.occupiedValue.forEach((container) => {
      this.occupiedByCode.set(container.code, container)
      if (Number(container.size) === 40) {
        this.occupiedByCode.set(`${container.block}${Number(container.bay) + 1}${container.row}${container.level}`, container)
      }
    })
    this.slots = []
    this.selected = null
    this.showAreas = false
    this.sectionByCode = new Map()
    this.sectionsValue.forEach((section) => section.slots.forEach((code) => this.sectionByCode.set(code, section)))
    this.setupScene()
    this.buildBlocks()
    this.buildOccupiedContainers()
    this.buildDesycon()
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

  layout(code, index) {
    return BLOCK_LAYOUT[code] || { origin: [index * FALLBACK_ORIGIN_STEP, 300] }
  }

  buildBlocks() {
    const placed = []
    this.blockViews = {}
    this.blocksValue.forEach((block, index) => {
      const { origin: [originX, originZ], rotated = false, reverseRows = false } = this.layout(block.code, index)
      const bayLength = block.bays * (SLOT.length + GAP.bay)
      const rowLength = block.rows * (SLOT.width + GAP.row)
      const width = rotated ? rowLength : bayLength
      const depth = rotated ? bayLength : rowLength

      const ground = new THREE.Mesh(
        new THREE.PlaneGeometry(width + 2, depth + 2),
        new THREE.MeshBasicMaterial({ color: COLORS.ground })
      )
      ground.rotation.x = -Math.PI / 2
      ground.position.set(originX + width / 2, -0.05, originZ + depth / 2)
      this.scene.add(ground)
      const label = this.addLabel(block.code, originX + width / 2, originZ - 4, 6)
      this.blockViews[block.code] = {
        ground, label, center: [originX + width / 2, originZ + depth / 2], extent: Math.max(width, depth),
        bounds: { minX: originX, maxX: originX + width, minZ: originZ, maxZ: originZ + depth }
      }

      for (let level = 1; level <= block.levels; level++) {
        for (let row = 0; row < block.rows; row++) {
          for (let bay = 1; bay <= block.bays; bay++) {
            const letter = String.fromCharCode(65 + row)
            const alongBays = (bay - 1) * (SLOT.length + GAP.bay) + SLOT.length / 2
            const rowIndex = reverseRows ? block.rows - 1 - row : row
            const alongRows = rowIndex * (SLOT.width + GAP.row) + SLOT.width / 2
            placed.push({
              code: `${block.code}${bay}${letter}${level}`, block: block.code, bay, row: letter, level, rotated,
              position: new THREE.Vector3(
                originX + (rotated ? alongRows : alongBays),
                (level - 1) * SLOT.height + SLOT.height / 2,
                originZ + (rotated ? alongBays : alongRows)
              )
            })
          }
        }
      }
    })

    this.slots = placed
    this.units = this.buildUnits(placed)
    this.mesh = new THREE.InstancedMesh(
      new THREE.BoxGeometry(SLOT.length * 0.96, SLOT.height * 0.96, SLOT.width * 0.96),
      new THREE.MeshStandardMaterial({ transparent: true, opacity: 0.55, roughness: 0.6 }),
      this.units.length
    )
    this.scene.add(this.mesh)
    this.paint()
  }

  // Cada par libre de bahías (impar + siguiente) se dibuja como un contenedor de 40 pies.
  // Las bahías ocupadas por contenedores de 20 pies se mantienen separadas.
  buildUnits(placed) {
    const byKey = new Map(placed.map((slot) => [`${slot.block}|${slot.row}|${slot.level}|${slot.bay}`, slot]))
    const partnerOf = (slot) => slot.bay % 2 === 1 ? byKey.get(`${slot.block}|${slot.row}|${slot.level}|${slot.bay + 1}`) : null
    const mergeable = (slot, partner) => partner && !this.isSplit(slot) && !this.isSplit(partner)
    const units = []
    placed.forEach((slot) => {
      const partner = partnerOf(slot)
      if (slot.bay % 2 === 0) {
        const anchor = byKey.get(`${slot.block}|${slot.row}|${slot.level}|${slot.bay - 1}`)
        if (mergeable(anchor, slot)) return
      }
      if (mergeable(slot, partner)) {
        units.push({
          slots: [ slot, partner ], block: slot.block, level: slot.level, rotated: slot.rotated,
          position: slot.position.clone().add(partner.position).multiplyScalar(0.5),
          scale: (2 * SLOT.length + GAP.bay) / SLOT.length
        })
      } else {
        units.push({ slots: [ slot ], block: slot.block, level: slot.level, rotated: slot.rotated, position: slot.position, scale: 1 })
      }
    })
    return units
  }

  isSplit(slot) {
    return this.disabledCodes.has(slot.code) || Number(this.occupiedByCode.get(slot.code)?.size) === 20
  }

  containerColor(container) {
    return /^#[0-9a-f]{6}$/i.test(container.color || "") ? parseInt(container.color.slice(1), 16) : COLORS.occupied
  }

  buildOccupiedContainers() {
    const slotsByCode = new Map(this.slots.map((slot) => [slot.code, slot]))
    this.occupiedContainers = this.occupiedValue.flatMap((record) => {
      const anchor = slotsByCode.get(record.code)
      if (!anchor) return []

      const slots = [anchor]
      if (Number(record.size) === 40) {
        const companion = slotsByCode.get(`${record.block}${Number(record.bay) + 1}${record.row}${record.level}`)
        if (companion) slots.push(companion)
      }
      const position = slots.length === 2
        ? slots[0].position.clone().add(slots[1].position).multiplyScalar(0.5)
        : anchor.position.clone()
      return [{
        ...record,
        slots,
        position,
        block: anchor.block,
        level: anchor.level,
        rotated: anchor.rotated
      }]
    })

    this.containerMeshes = []
    const sizes = [20, 40]
    sizes.forEach((size) => {
      const containers = this.occupiedContainers.filter((container) => Number(container.size) === size)
      if (!containers.length) return

      const length = size === 40 ? 2 * SLOT.length + GAP.bay : SLOT.length
      const width = SLOT.width * 0.9
      const height = SLOT.height * 0.92
      const scale = new THREE.Vector3(1, 1, 1)
      const transform = new THREE.Matrix4()
      const body = new THREE.InstancedMesh(
        new THREE.BoxGeometry(length * 0.94, height, width),
        new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.85, metalness: 0 }),
        containers.length
      )
      const bodyMatrices = []
      const ribMatrices = []
      const ribOwners = []
      const cornerMatrices = []
      const cornerOwners = []
      const ribCount = Math.max(12, Math.floor(length / 0.3))
      const ribs = new THREE.InstancedMesh(
        new THREE.BoxGeometry(0.045, height * 0.9, 0.035),
        new THREE.MeshStandardMaterial({ color: COLORS.containerRib, roughness: 0.65, metalness: 0.2 }),
        containers.length * ribCount * 2
      )
      const corners = new THREE.InstancedMesh(
        new THREE.BoxGeometry(0.14, height * 0.96, 0.14),
        new THREE.MeshStandardMaterial({ color: COLORS.corner, roughness: 0.65, metalness: 0.15 }),
        containers.length * 4
      )

      containers.forEach((container, index) => {
        const rotation = container.rotated ? ROTATED : UPRIGHT
        const bodyMatrix = transform.compose(container.position, rotation, scale).clone()
        body.setMatrixAt(index, bodyMatrix)
        bodyMatrices.push(bodyMatrix)

        for (let rib = 0; rib < ribCount; rib++) {
          const x = -length / 2 + ((rib + 0.5) * length) / ribCount
          for (const side of [-1, 1]) {
            const localPosition = new THREE.Vector3(x, 0, side * width * 0.49).applyQuaternion(rotation).add(container.position)
            const ribMatrix = transform.compose(localPosition, rotation, scale).clone()
            ribs.setMatrixAt(ribMatrices.length, ribMatrix)
            ribMatrices.push(ribMatrix)
            ribOwners.push(index)
          }
        }

        for (const [corner, [x, z]] of [
          [0, [-length / 2, -width / 2]], [1, [-length / 2, width / 2]],
          [2, [length / 2, -width / 2]], [3, [length / 2, width / 2]]
        ]) {
          const localPosition = new THREE.Vector3(x, 0, z).applyQuaternion(rotation).add(container.position)
          const cornerMatrix = transform.compose(localPosition, rotation, scale).clone()
          corners.setMatrixAt(cornerMatrices.length, cornerMatrix)
          cornerMatrices.push(cornerMatrix)
          cornerOwners.push(index)
        }
      })

      for (const [mesh, matrices, owners, kind] of [
        [body, bodyMatrices, containers.map((_container, index) => index), "body"],
        [ribs, ribMatrices, ribOwners, "detail"],
        [corners, cornerMatrices, cornerOwners, "detail"]
      ]) {
        mesh.instanceMatrix.needsUpdate = true
        mesh.computeBoundingSphere()
        this.scene.add(mesh)
        this.containerMeshes.push({ mesh, containers, matrices, owners, kind })
      }
    })
  }

  visibleOccupiedContainer(container) {
    const level = this.hasLevelTarget ? this.levelTarget.value : ""
    const block = this.currentBlock()
    return (!level || container.level === Number(level)) && (!block || container.block === block)
  }

  // Fondo y etiqueta que agrupan los bloques CFS bajo el nombre de DesyCon.
  buildDesycon() {
    const views = DESYCON_BLOCKS.map((code) => this.blockViews[code]).filter(Boolean)
    if (!views.length) return

    const minX = Math.min(...views.map((view) => view.bounds.minX)) - 4
    const maxX = Math.max(...views.map((view) => view.bounds.maxX)) + 4
    const minZ = Math.min(...views.map((view) => view.bounds.minZ)) - 4
    const maxZ = Math.max(...views.map((view) => view.bounds.maxZ)) + 4
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(maxX - minX, maxZ - minZ),
      new THREE.MeshBasicMaterial({ color: COLORS.area })
    )
    ground.rotation.x = -Math.PI / 2
    ground.position.set((minX + maxX) / 2, -0.1, (minZ + maxZ) / 2)
    this.scene.add(ground)
    const label = this.addLabel(this.labelsValue.desycon, (minX + maxX) / 2, minZ - 12, 8)
    this.desycon = { ground, label }
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
    if (this.desycon) this.desycon.ground.visible = this.desycon.label.visible = !block
    const matrix = new THREE.Matrix4()
    const scale = new THREE.Vector3()
    const hidden = new THREE.Matrix4().makeScale(0, 0, 0)
    const color = new THREE.Color()

    this.units.forEach((unit, index) => {
      const visible = (!level || unit.level === Number(level)) && (!block || unit.block === block)
      const codes = unit.slots.map((slot) => slot.code)
      const occupant = codes.map((code) => this.occupiedByCode.get(code)).find(Boolean)
      // El contenedor ya ocupa la posición; el cubo translúcido alteraría su color.
      this.mesh.setMatrixAt(index, visible && !occupant ? matrix.compose(unit.position, unit.rotated ? ROTATED : UPRIGHT, scale.set(unit.scale, 1, 1)) : hidden)
      const state = codes.includes(this.selected) ? "selected" : occupant ? "occupied" : codes.some((code) => this.disabledCodes.has(code)) ? "disabled" : "enabled"
      if (this.showAreas && state !== "selected" && state !== "occupied") {
        const section = this.sectionByCode.get(codes[0])
        this.mesh.setColorAt(index, section ? color.set(section.color) : color.setHex(COLORS.unassigned))
      } else {
        this.mesh.setColorAt(index, color.setHex(COLORS[state]))
      }
    })
    this.containerMeshes?.forEach(({ mesh, containers, matrices, owners, kind }) => {
      owners.forEach((containerIndex, instanceIndex) => {
        const container = containers[containerIndex]
        mesh.setMatrixAt(instanceIndex, this.visibleOccupiedContainer(container) ? matrices[instanceIndex] : hidden)
        if (kind === "body") {
          mesh.setColorAt(instanceIndex, color.setHex(container.slots.some((slot) => slot.code === this.selected) ? COLORS.selected : this.containerColor(container)))
        }
      })
      mesh.instanceMatrix.needsUpdate = true
      if (kind === "body") mesh.instanceColor.needsUpdate = true
      mesh.computeBoundingSphere()
    })
    this.mesh.instanceMatrix.needsUpdate = true
    this.mesh.instanceColor.needsUpdate = true
    this.mesh.computeBoundingSphere()
    this.render()
  }

  toggleAreas() {
    this.showAreas = !this.showAreas
    this.areasToggleTarget.setAttribute("aria-pressed", String(this.showAreas))
    this.legendTarget.hidden = !this.showAreas
    this.paint()
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

    const occupiedHit = this.containerMeshes.filter(({ kind }) => kind === "body").flatMap(({ mesh, containers }) =>
      this.raycaster.intersectObject(mesh)
        .filter((hit) => this.visibleOccupiedContainer(containers[hit.instanceId]))
        .map((hit) => containers[hit.instanceId])
    )[0]
    const hits = occupiedHit ? [] : this.raycaster.intersectObject(this.mesh).filter((hit) => this.visibleInstance(hit.instanceId))
    const unit = occupiedHit || (hits.length ? this.units[hits[0].instanceId] : null)
    if (unit) {
      this.selected = unit.slots[0].code
      this.showInfo(unit)
    } else {
      this.selected = null
      this.showInfo(null)
    }
    this.paint()
  }

  visibleInstance(index) {
    const level = this.hasLevelTarget ? this.levelTarget.value : ""
    const block = this.currentBlock()
    const unit = this.units[index]
    return (!level || unit.level === Number(level)) && (!block || unit.block === block)
  }

  showInfo(unit) {
    const labels = this.labelsValue
    let html = `<p class="text-sm text-slate-500">${labels.hint}</p>`
    if (unit) {
      const [first] = unit.slots
      const occupant = unit.container || unit.slots.map((slot) => this.occupiedByCode.get(slot.code)).find(Boolean)
      const state = occupant ? labels.occupied : unit.slots.some((slot) => this.disabledCodes.has(slot.code)) ? labels.disabled : labels.enabled
      const bays = unit.slots.map((slot) => slot.bay).join("-")
      html = `<p class="font-mono text-xl font-bold text-slate-900">${unit.slots.map((slot) => slot.code).join(" · ")}</p>
              <p class="text-sm text-slate-600">${labels.block} ${first.block} · ${labels.bay} ${bays} · ${labels.row} ${first.row} · ${labels.level} ${first.level}</p>
              <p class="mt-1 text-sm font-medium text-slate-800">${state}${occupant ? ` · ${occupant.number} · ${occupant.size}'${occupant.status ? ` · ${occupant.status}` : ""}` : ""}</p>${this.sectionInfo(first)}`
    }
    this.infoTarget.innerHTML = html
  }

  sectionInfo(slot) {
    const section = this.sectionByCode.get(slot.code)
    if (!section) return ""
    const detail = section.detail ? ` · ${section.detail}` : ""
    return `<p class="text-sm text-slate-600">${this.labelsValue.section}: ${section.label}${detail}</p>`
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
      this.controls.target.set(115, 0, 105)
      this.camera.position.set(115, 300, 300)
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
