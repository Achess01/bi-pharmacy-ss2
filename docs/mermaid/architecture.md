# Arquitectura del sistema - Código Mermaid

```
graph TD
    %% Fuentes de Datos
    subgraph Fuentes_OLTP [Fuentes de Datos - Sistemas Operativos]
        direction LR
        S1[(Compras)]
        S2[(Producción - Laboratorios)]
        S3[(Logística y Bodega)]
        S4[(POS Sucursal 1 - Cloud)]
        S5[(POS Sucursal N - Cloud)]
    end

    %% Capa de Integración
    subgraph ETL_Process [Capa de Integración - ETL]
        direction TB
        Trans[Transformación: Limpieza y Normalización]
        Load[Carga Incremental]
        
        Trans --> Load
    end

    %% Capa de Almacenamiento
    subgraph Data_Storage [Data Warehouse Central]
        DWH[(Data Warehouse Central)]
        
        subgraph Data_Marts [Data Marts Especializados]
            DM_Ventas[DM Ventas y Demanda]
            DM_Inv[DM Inventario y Logística]
            DM_Prod[DM Producción y Eficiencia]
        end
        
        DWH --> DM_Ventas
        DWH --> DM_Inv
        DWH --> DM_Prod
    end

    %% Capa de Presentación
    subgraph Analytics_Layer [Capa de Análisis y BI]
        direction TB
        Cubes[Cubos OLAP / Procesamiento Analítico]
        Dashboards[Dashboards Interactivos - Apache Superset]
        KPIs[Alertas y KPIs de Negocio]
        
        Cubes --> Dashboards
        Cubes --> KPIs
    end

    %% Conexiones principales
    S1 & S2 & S3 & S4 & S5 --> Trans
    Load --> DWH
    DM_Ventas & DM_Inv & DM_Prod --> Cubes

    %% Estilos
    style DWH fill:#f9f,stroke:#333,stroke-width:4px
    style ETL_Process fill:#e1f5fe,stroke:#01579b
    style Analytics_Layer fill:#fff3e0,stroke:#e65100
```