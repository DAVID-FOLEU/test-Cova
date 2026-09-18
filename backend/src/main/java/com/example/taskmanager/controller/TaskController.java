package com.example.taskmanager.controller;

import com.example.taskmanager.model.Task;
import com.example.taskmanager.model.TaskStatus;
import com.example.taskmanager.model.UserCova;
import com.example.taskmanager.repository.TaskRepository;
import com.example.taskmanager.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/tasks")
@CrossOrigin(origins = "*")
public class TaskController {

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private UserRepository userRepository;

    // Route : GET /api/tasks?userId=1 (Récupérer les tâches d'un utilisateur)
    @GetMapping
    public ResponseEntity<?> getTasks(@RequestParam Long userId, Authentication authentication) {
        ResponseEntity<?> accessCheck = verifyUser(userId, authentication);
        if (accessCheck != null)
            return accessCheck;
        return ResponseEntity.ok(taskRepository.findByUserCovaId(userId));
    }

    // Route optionnelle : GET /api/tasks/status?userId=1&status=IN_PROGRESS
    // (Filtrer par statut)
    @GetMapping("/status")
    public ResponseEntity<?> getTasksByStatus(@RequestParam Long userId, @RequestParam TaskStatus status,
            Authentication authentication) {
        ResponseEntity<?> accessCheck = verifyUser(userId, authentication);
        if (accessCheck != null)
            return accessCheck;
        return ResponseEntity.ok(taskRepository.findByUserCovaIdAndStatus(userId, status));
    }

    // Route : POST /api/tasks?userId=1 (Créer une tâche)
    @PostMapping
    public ResponseEntity<?> createTask(@RequestParam Long userId, @RequestBody Task task,
            Authentication authentication) {
        ResponseEntity<?> accessCheck = verifyUser(userId, authentication);
        if (accessCheck != null)
            return accessCheck;
        UserCova user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            return ResponseEntity.badRequest().body("Utilisateur non trouvé.");
        }

        // Si aucun statut n'est fourni lors de la création, on force PENDING
        if (task.getStatus() == null) {
            task.setStatus(TaskStatus.PENDING);
        }

        task.setUserCova(user);
        Task savedTask = taskRepository.save(task);
        return ResponseEntity.ok(savedTask);
    }

    // Route : PUT /api/tasks/{id} (Modifier une tâche)
    @PutMapping("/{id}")
    public ResponseEntity<?> updateTask(@PathVariable Long id, @RequestParam Long userId, @RequestBody Task taskDetails,
            Authentication authentication) {
        ResponseEntity<?> accessCheck = verifyUser(userId, authentication);
        if (accessCheck != null)
            return accessCheck;
        Task task = taskRepository.findById(id).orElse(null);
        if (task == null || !task.getUserCova().getId().equals(userId)) {
            return ResponseEntity.notFound().build();
        }

        task.setTitle(taskDetails.getTitle());
        task.setDescription(taskDetails.getDescription());

        // Mise à jour du statut (ex: passage à TaskStatus.IN_PROGRESS)
        if (taskDetails.getStatus() != null) {
            task.setStatus(taskDetails.getStatus());
        }

        task.setUpdatedAt(LocalDateTime.now());

        Task updatedTask = taskRepository.save(task);
        return ResponseEntity.ok(updatedTask);
    }

    // Route : DELETE /api/tasks/{id} (Supprimer une tâche)
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteTask(@PathVariable Long id, @RequestParam Long userId,
            Authentication authentication) {
        ResponseEntity<?> accessCheck = verifyUser(userId, authentication);
        if (accessCheck != null)
            return accessCheck;
        Task task = taskRepository.findById(id).orElse(null);
        if (task == null || !task.getUserCova().getId().equals(userId)) {
            return ResponseEntity.notFound().build();
        }
        taskRepository.delete(task);
        return ResponseEntity.ok("Tâche supprimée avec succès.");
    }

    private ResponseEntity<?> verifyUser(Long userId, Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(401).body("Authentification requise.");
        }

        UserCova authenticatedUser = userRepository.findByEmail(authentication.getName()).orElse(null);
        if (authenticatedUser == null || !authenticatedUser.getId().equals(userId)) {
            return ResponseEntity.status(403).body("Accès interdit.");
        }
        return null;
    }
}