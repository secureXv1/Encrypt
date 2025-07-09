import SwiftUI

struct TextoSimple: Identifiable, Equatable {
    let id = UUID()
    let nombre: String
    let url: URL
    let fecha: Date
}

struct CrearTextoView: View {
    @State private var textos: [TextoSimple] = []
    @State private var mostrarFormulario = false
    @State private var mostrarLector = false
    @State private var notaParaEditar: NotaParaEditar? = nil
    @State private var notaLeyendo: TextoSimple? = nil
    @State private var contenidoLeyendo: String = ""
    @State private var notaSeleccionadaParaCifrar: TextoSimple? = nil
    @State private var mostrarSheetCifrado = false
    @State private var mostrarAlertaNombreExistente = false
    @State private var mensajeAlerta = ""
    
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    var body: some View {
        VStack {
            // TÍTULO Y BOTÓN +
            HStack {
                Text("Notas de texto")
                    .font(.title2).bold()
                Spacer()
                Button(action: {
                    notaParaEditar = NotaParaEditar(nota: nil, contenido: "")
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            // LISTA DE NOTAS
            List {
                ForEach(textos) { nota in
                    Button {
                        editarNota(nota) // ahora edita en lugar de leer
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.indigo)
                            VStack(alignment: .leading) {
                                Text(nota.nombre)
                                    .bold()
                                Text("Modificada el \(formatDate(nota.fecha))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            eliminarNota(nota)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        Button {
                            notaSeleccionadaParaCifrar = nota
                            mostrarSheetCifrado = true
                        } label: {
                            Label("Cifrar", systemImage: "lock")
                        }.tint(.blue)
                    }
                }
            }
        }
        .onAppear(perform: cargarNotas)

        // Editor
        .sheet(item: $notaParaEditar) { item in
            EditorTextoView(
                nombreInicial: item.nota?.nombre.replacingOccurrences(of: ".txt", with: "") ?? "",
                contenidoInicial: item.contenido,
                onGuardar: { nuevoNombre, nuevoContenido in
                    let nombreFinal = nuevoNombre.hasSuffix(".txt") ? nuevoNombre : "\(nuevoNombre).txt"
                    let urlNuevo = folder.appendingPathComponent(nombreFinal)

                    // ⚠️ Si estamos editando una nota existente
                    if let notaExistente = item.nota {
                        // Si cambió el nombre, verificar si ya existe otro archivo con ese nombre
                        if notaExistente.url.lastPathComponent != nombreFinal,
                           FileManager.default.fileExists(atPath: urlNuevo.path) {
                            mensajeAlerta = "Ya existe una nota con ese nombre."
                            mostrarAlertaNombreExistente = true
                            return
                        }

                        // Si cambió el nombre, eliminar la anterior
                        if notaExistente.url != urlNuevo {
                            try? FileManager.default.removeItem(at: notaExistente.url)
                        }
                    } else {
                        // Es una nueva nota, validar si ya existe
                        if FileManager.default.fileExists(atPath: urlNuevo.path) {
                            mensajeAlerta = "Ya existe una nota con ese nombre."
                            mostrarAlertaNombreExistente = true
                            return
                        }
                    }

                    do {
                        try nuevoContenido.write(to: urlNuevo, atomically: true, encoding: .utf8)
                        cargarNotas()
                        notaParaEditar = nil
                    } catch {
                        print("❌ Error al guardar nota: \(error)")
                    }
                },
                onCifrar: { nombre, contenido in
                    let nombreFinal = nombre.hasSuffix(".txt") ? nombre : "\(nombre).txt"
                    let url = folder.appendingPathComponent(nombreFinal)

                    if let notaExistente = item.nota {
                        if notaExistente.url.lastPathComponent != nombreFinal,
                           FileManager.default.fileExists(atPath: url.path) {
                            mensajeAlerta = "Ya existe una nota con ese nombre."
                            mostrarAlertaNombreExistente = true
                            return
                        }

                        if notaExistente.url != url {
                            try? FileManager.default.removeItem(at: notaExistente.url)
                        }
                    } else {
                        if FileManager.default.fileExists(atPath: url.path) {
                            mensajeAlerta = "Ya existe una nota con ese nombre."
                            mostrarAlertaNombreExistente = true
                            return
                        }
                    }

                    do {
                        try contenido.write(to: url, atomically: true, encoding: .utf8)
                        cargarNotas()
                        notaParaEditar = nil
                        notaSeleccionadaParaCifrar = TextoSimple(nombre: nombreFinal, url: url, fecha: Date())
                        mostrarSheetCifrado = true
                    } catch {
                        print("❌ Error al guardar nota para cifrar: \(error)")
                    }
                }
            )
        }
        // Lector
        .sheet(isPresented: $mostrarLector) {
            NavigationView {
                ScrollView {
                    Text(contenidoLeyendo)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(notaLeyendo?.nombre ?? "Nota")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") {
                            mostrarLector = false
                        }
                    }
                }
            }
        }

        // Sheet para cifrado con interfaz avanzada
        .sheet(item: $notaSeleccionadaParaCifrar) { nota in
            SheetFormularioCifrado(
                archivoURL: nota.url,
                onFinish: { _ in
                    notaSeleccionadaParaCifrar = nil
                },
                isPresented: Binding(
                    get: { notaSeleccionadaParaCifrar != nil },
                    set: { newValue in
                        if !newValue { notaSeleccionadaParaCifrar = nil }
                    }
                )
            )
        }
        .alert(isPresented: $mostrarAlertaNombreExistente) {
            Alert(
                title: Text("Nombre en uso"),
                message: Text(mensajeAlerta),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // CARGA INICIAL
    func cargarNotas() {
        do {
            let archivos = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
            textos = archivos.filter { $0.pathExtension == "txt" }.compactMap {
                let fecha = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                return TextoSimple(nombre: $0.lastPathComponent, url: $0, fecha: fecha)
            }.sorted { $0.fecha > $1.fecha }
        } catch {
            print("❌ Error cargando notas: \(error)")
        }
    }

    func editarNota(_ nota: TextoSimple) {
        do {
            let contenido = try String(contentsOf: nota.url, encoding: .utf8)
            notaParaEditar = NotaParaEditar(nota: nota, contenido: contenido)
        } catch {
            print("❌ Error leyendo nota: \(error)")
        }
    }


    func leerNota(_ nota: TextoSimple) {
        do {
            contenidoLeyendo = try String(contentsOf: nota.url, encoding: .utf8)
            notaLeyendo = nota
            mostrarLector = true
        } catch {
            print("❌ Error leyendo nota: \(error)")
        }
    }

    func eliminarNota(_ nota: TextoSimple) {
        do {
            try FileManager.default.removeItem(at: nota.url)
            cargarNotas()
        } catch {
            print("❌ Error al eliminar nota: \(error)")
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NotaParaEditar: Identifiable {
    let id = UUID()
    let nota: TextoSimple? // Puede ser nil al crear nueva nota
    let contenido: String
}

