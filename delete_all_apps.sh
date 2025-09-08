#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚨 WARNING: This script will DELETE ALL applications from core-apps and new-apps folders!${NC}"
echo -e "${YELLOW}This action is IRREVERSIBLE and will remove all deployed applications from your k3s cluster.${NC}"
echo
echo "Applications that will be deleted:"

# List all applications
echo -e "\n${YELLOW}Core Apps:${NC}"
for app_file in argocd/core-apps/*.yaml; do
    if [ -f "$app_file" ]; then
        app_name=$(grep "name:" "$app_file" | head -1 | awk '{print $2}')
        echo "  - $app_name ($(basename "$app_file"))"
    fi
done

echo -e "\n${YELLOW}New Apps:${NC}"
for app_file in argocd/new-apps/*.yaml; do
    if [ -f "$app_file" ]; then
        app_name=$(grep "name:" "$app_file" | head -1 | awk '{print $2}')
        echo "  - $app_name ($(basename "$app_file"))"
    fi
done

echo
read -p "Are you absolutely sure you want to proceed? Type 'DELETE_ALL' to confirm: " confirmation

if [ "$confirmation" != "DELETE_ALL" ]; then
    echo -e "${RED}❌ Operation cancelled.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}🔄 Starting deletion process...${NC}"

# Function to extract the source path from an ArgoCD application YAML
get_source_path() {
    local app_file=$1
    grep -A 10 "source:" "$app_file" | grep "path:" | head -1 | sed 's/.*path: *//; s/"//g'
}

# Function to check if a path has Kustomization configuration
has_kustomization() {
    local path=$1
    [ -f "$path/kustomization.yaml" ] || [ -f "$path/kustomization.yml" ] || [ -f "$path/Kustomization" ]
}

# Function to delete applications from a directory
delete_apps_from_dir() {
    local dir=$1
    local dir_name=$2
    
    echo -e "\n${YELLOW}Deleting applications from $dir_name...${NC}"
    
    for app_file in "$dir"/*.yaml; do
        if [ -f "$app_file" ]; then
            app_name=$(grep "name:" "$app_file" | head -1 | awk '{print $2}')
            source_path=$(get_source_path "$app_file")
            
            echo -e "  🗑️  Deleting $app_name..."
            
            # First delete the ArgoCD application itself
            kubectl delete -f "$app_file" --ignore-not-found=true
            
            if [ $? -eq 0 ]; then
                echo -e "    ${GREEN}✅ ArgoCD application deleted${NC}"
            else
                echo -e "    ${RED}❌ Failed to delete ArgoCD application${NC}"
                continue
            fi
            
            # If there's a source path, check if it has Kustomization and delete resources
            if [ -n "$source_path" ] && [ -d "$source_path" ]; then
                if has_kustomization "$source_path"; then
                    echo -e "    📦 Kustomization found at $source_path, deleting resources with -k"
                    kubectl delete -k "$source_path" --ignore-not-found=true
                    if [ $? -eq 0 ]; then
                        echo -e "    ${GREEN}✅ Kustomized resources deleted${NC}"
                    else
                        echo -e "    ${RED}❌ Failed to delete Kustomized resources${NC}"
                    fi
                else
                    echo -e "    📁 Deleting YAML resources from $source_path"
                    kubectl delete -f "$source_path" --ignore-not-found=true --recursive=true
                    if [ $? -eq 0 ]; then
                        echo -e "    ${GREEN}✅ Resources deleted${NC}"
                    else
                        echo -e "    ${RED}❌ Failed to delete resources${NC}"
                    fi
                fi
            else
                echo -e "    ${YELLOW}⚠️  No source path found or path doesn't exist: $source_path${NC}"
            fi
        fi
    done
}

# Delete applications from core-apps
if [ -d "argocd/core-apps" ]; then
    delete_apps_from_dir "argocd/core-apps" "core-apps"
else
    echo -e "${RED}❌ core-apps directory not found${NC}"
fi

# Delete applications from new-apps
if [ -d "argocd/new-apps" ]; then
    delete_apps_from_dir "argocd/new-apps" "new-apps"
else
    echo -e "${RED}❌ new-apps directory not found${NC}"
fi

echo -e "\n${GREEN}🎉 Deletion process completed!${NC}"
echo -e "${YELLOW}📝 Note: The YAML files are still present in the directories.${NC}"
echo -e "${YELLOW}   ArgoCD applications have been removed from the cluster.${NC}"
echo -e "${YELLOW}   Kubernetes resources may take some time to be fully cleaned up.${NC}"

echo -e "\n${YELLOW}🔍 You can check the status with:${NC}"
echo "  kubectl get applications -n argocd"
echo "  kubectl get all --all-namespaces"