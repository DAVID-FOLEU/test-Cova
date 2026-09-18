package com.example.taskmanager.repository;

import com.example.taskmanager.model.Task;
import com.example.taskmanager.model.TaskStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {
    // Récupère uniquement les tâches qui appartiennent à l'utilisateur connecté
    List<Task> findByUserCovaId(Long userCovaId);

    // Récupère les tâches filtrées par utilisateur et par statut (PENDING, IN_PROGRESS, COMPLETED)
    List<Task> findByUserCovaIdAndStatus(Long userCovaId, TaskStatus status);
}